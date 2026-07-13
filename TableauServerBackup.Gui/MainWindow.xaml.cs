using System.Collections.ObjectModel;
using System.IO;
using System.Security.Principal;
using System.Windows;
using TableauServerBackup.Gui.Models;
using TableauServerBackup.Gui.Services;
using WinForms = System.Windows.Forms;

namespace TableauServerBackup.Gui;

public partial class MainWindow : Window
{
    private readonly EnvironmentSettingsService _environmentSettings = new();
    private readonly TaskSchedulerService _taskScheduler = new();
    private readonly List<SettingEntry> _allSettings;
    private readonly string _projectRoot;

    public ObservableCollection<SettingEntry> GeneralSettings { get; } = [];
    public ObservableCollection<SettingEntry> MaintenanceSettings { get; } = [];
    public ObservableCollection<SettingEntry> EmailSettings { get; } = [];

    public MainWindow()
    {
        InitializeComponent();
        _projectRoot = FindProjectRoot();
        _allSettings = _environmentSettings.CreateSettings().ToList();
        PopulateGroups();
        DataContext = this;

        BatchPathTextBox.Text = Path.Combine(_projectRoot, "TableauServerBackup.bat");
        TaskAccountTextBox.Text = WindowsIdentity.GetCurrent().Name;
        LoadSettings();
        InspectTask();
    }

    private void PopulateGroups()
    {
        var emailNames = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
        {
            "TABLEAU_BACKUP_MAIL_ENABLED", "TABLEAU_BACKUP_MAIL_SMTP_SERVER", "TABLEAU_BACKUP_MAIL_SMTP_PORT",
            "TABLEAU_BACKUP_MAIL_USE_SSL", "TABLEAU_BACKUP_MAIL_FROM", "TABLEAU_BACKUP_MAIL_TO",
            "TABLEAU_BACKUP_MAIL_CC", "TABLEAU_BACKUP_MAIL_BCC", "TABLEAU_BACKUP_MAIL_SUBJECT_PREFIX",
            "TABLEAU_BACKUP_MAIL_DELIVERY_NOTIFICATION"
        };
        var maintenanceNames = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
        {
            "TABLEAU_BACKUP_MAINTENANCE_CLEANUP_ENABLED", "TABLEAU_BACKUP_TABLEAU_LOG_RETENTION_DAYS",
            "TABLEAU_BACKUP_HTTP_REQUESTS_CLEANUP_ENABLED", "TABLEAU_BACKUP_HTTP_REQUESTS_RETENTION_DAYS",
            "TABLEAU_BACKUP_REINDEX_ENABLED"
        };

        foreach (var setting in _allSettings)
        {
            if (emailNames.Contains(setting.EnvironmentVariable))
            {
                EmailSettings.Add(setting);
            }
            else if (maintenanceNames.Contains(setting.EnvironmentVariable))
            {
                MaintenanceSettings.Add(setting);
            }
            else
            {
                GeneralSettings.Add(setting);
            }
        }
    }

    private EnvironmentVariableTarget SelectedTarget => ScopeComboBox.SelectedIndex == 0
        ? EnvironmentVariableTarget.User
        : EnvironmentVariableTarget.Machine;

    private void ReloadSettings_Click(object sender, RoutedEventArgs e) => LoadSettings();

    private void LoadSettings()
    {
        try
        {
            _environmentSettings.Load(_allSettings, SelectedTarget);
            SetStatus($"Loaded {_allSettings.Count} settings from {SelectedTarget} scope.");
        }
        catch (Exception exception)
        {
            SetStatus($"Could not load settings: {exception.Message}", true);
        }
    }

    private void ApplySettings_Click(object sender, RoutedEventArgs e)
    {
        var errors = EnvironmentSettingsService.Validate(_allSettings);
        if (errors.Count > 0)
        {
            SetStatus(string.Join(" ", errors), true);
            return;
        }

        try
        {
            _environmentSettings.Save(_allSettings, SelectedTarget);
            if (SelectedTarget != EnvironmentVariableTarget.Process)
            {
                _environmentSettings.Save(_allSettings, EnvironmentVariableTarget.Process);
            }

            SetStatus($"Saved {_allSettings.Count} settings to {SelectedTarget} scope.");
        }
        catch (UnauthorizedAccessException)
        {
            SetStatus("Windows denied access. Restart this app as administrator to save Machine-scope settings, or select User scope.", true);
        }
        catch (Exception exception)
        {
            SetStatus($"Could not save settings: {exception.Message}", true);
        }
    }

    private void BrowseTableauDirectory_Click(object sender, RoutedEventArgs e) =>
        BrowseForFolder("TABLEAU_SERVER_DATA_DIR");

    private void BrowseBackupRoot_Click(object sender, RoutedEventArgs e) =>
        BrowseForFolder("TABLEAU_BACKUP_ROOT");

    private void BrowseForFolder(string environmentVariable)
    {
        using var dialog = new WinForms.FolderBrowserDialog { UseDescriptionForTitle = true, Description = "Select folder" };
        if (dialog.ShowDialog() == WinForms.DialogResult.OK)
        {
            _allSettings.Single(setting => setting.EnvironmentVariable == environmentVariable).Value = dialog.SelectedPath;
        }
    }

    private void InspectTask_Click(object sender, RoutedEventArgs e) => InspectTask();

    private void InspectTask()
    {
        try
        {
            var details = _taskScheduler.Inspect(TaskNameTextBox.Text.Trim());
            TaskStateText.Text = details.State;
            TaskStatusAccountText.Text = details.UserName;
            TaskActionText.Text = details.ActionPath;
            TaskScheduleText.Text = details.StartBoundary;
            SetStatus(details.Exists ? "Scheduled task loaded." : "Scheduled task was not found.");
        }
        catch (Exception exception)
        {
            SetStatus($"Could not inspect the scheduled task: {exception.Message}", true);
        }
    }

    private void PreviewTask_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            SetStatus(_taskScheduler.Preview(TaskName(), BatchPathTextBox.Text, _projectRoot, TaskTime(), TaskInterval(), TaskAccountTextBox.Text));
        }
        catch (Exception exception)
        {
            SetStatus($"Could not preview the scheduled task: {exception.Message}", true);
        }
    }

    private void CreateOrUpdateTask_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            var credentialValue = TaskPasswordBox.Password;
            _taskScheduler.CreateOrUpdate(TaskName(), BatchPathTextBox.Text, _projectRoot, TaskTime(), TaskInterval(), TaskAccountTextBox.Text, credentialValue);
            TaskPasswordBox.Clear();
            InspectTask();
            SetStatus("Scheduled task created or updated.");
        }
        catch (Exception exception)
        {
            TaskPasswordBox.Clear();
            SetStatus($"Could not create or update the scheduled task: {exception.Message}", true);
        }
    }

    private void EnableTask_Click(object sender, RoutedEventArgs e) => SetTaskEnabled(true);
    private void DisableTask_Click(object sender, RoutedEventArgs e) => SetTaskEnabled(false);

    private void SetTaskEnabled(bool enabled)
    {
        try
        {
            _taskScheduler.SetEnabled(TaskName(), enabled);
            InspectTask();
            SetStatus(enabled ? "Scheduled task enabled." : "Scheduled task disabled.");
        }
        catch (Exception exception)
        {
            SetStatus($"Could not change the scheduled task: {exception.Message}", true);
        }
    }

    private void RemoveTask_Click(object sender, RoutedEventArgs e)
    {
        if (System.Windows.MessageBox.Show($"Remove scheduled task '{TaskName()}'? This does not delete backup files or configuration.", "Remove scheduled task", MessageBoxButton.YesNo, MessageBoxImage.Warning) != MessageBoxResult.Yes)
        {
            return;
        }

        try
        {
            _taskScheduler.Remove(TaskName());
            InspectTask();
            SetStatus("Scheduled task removed.");
        }
        catch (Exception exception)
        {
            SetStatus($"Could not remove the scheduled task: {exception.Message}", true);
        }
    }

    private string TaskName() => string.IsNullOrWhiteSpace(TaskNameTextBox.Text)
        ? throw new InvalidOperationException("Task name is required.")
        : TaskNameTextBox.Text.Trim();

    private TimeOnly TaskTime() => TimeOnly.TryParse(TaskTimeTextBox.Text, out var time)
        ? time
        : throw new InvalidOperationException("Daily start time must use 24-hour HH:mm format.");

    private int TaskInterval() => int.TryParse(TaskIntervalTextBox.Text, out var days) && days is >= 1 and <= 31
        ? days
        : throw new InvalidOperationException("Every N days must be between 1 and 31.");

    private void SetStatus(string text, bool isError = false)
    {
        StatusText.Text = text;
        StatusText.Foreground = isError ? System.Windows.Media.Brushes.DarkRed : System.Windows.Media.Brushes.Black;
    }

    private static string FindProjectRoot()
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null)
        {
            if (File.Exists(Path.Combine(directory.FullName, "TableauServerBackup.bat")))
            {
                return directory.FullName;
            }

            directory = directory.Parent;
        }

        return AppContext.BaseDirectory;
    }
}
