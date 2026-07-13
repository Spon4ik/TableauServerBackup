using System.Runtime.InteropServices;
using System.IO;

namespace TableauServerBackup.Gui.Services;

public sealed record ScheduledTaskDetails(bool Exists, string State, string UserName, string ActionPath, string StartBoundary);

public sealed class TaskSchedulerService
{
    private const int TaskTriggerDaily = 2;
    private const int TaskActionExecute = 0;
    private const int TaskCreateOrUpdate = 6;
    private const int TaskLogonStoredCredential = 1;
    private const int TaskInstancesIgnoreNew = 2;

    public ScheduledTaskDetails Inspect(string taskName)
    {
        dynamic folder = GetRootFolder();

        try
        {
            dynamic task = folder.GetTask(taskName);
            var actionPath = string.Empty;
            var startBoundary = string.Empty;

            if (task.Definition.Actions.Count > 0)
            {
                dynamic action = task.Definition.Actions.Item(1);
                actionPath = (string?)action.Path ?? string.Empty;
            }

            if (task.Definition.Triggers.Count > 0)
            {
                dynamic trigger = task.Definition.Triggers.Item(1);
                startBoundary = (string?)trigger.StartBoundary ?? string.Empty;
            }

            return new ScheduledTaskDetails(
                true,
                MapState((int)task.State),
                (string?)task.Definition.Principal.UserId ?? string.Empty,
                actionPath,
                startBoundary);
        }
        catch (COMException exception) when ((uint)exception.HResult == 0x80070002)
        {
            return new ScheduledTaskDetails(false, "Not found", string.Empty, string.Empty, string.Empty);
        }
    }

    public string Preview(string taskName, string batchPath, string workingDirectory, TimeOnly time, int daysInterval, string account)
    {
        ValidateDefinition(taskName, batchPath, workingDirectory, time, daysInterval, account, requireAccount: false);
        return $"Would create or update '{taskName}' to run '{batchPath}' daily at {time:HH\\:mm} every {daysInterval} day(s).";
    }

    public void CreateOrUpdate(string taskName, string batchPath, string workingDirectory, TimeOnly time, int daysInterval, string account, string credentialValue)
    {
        ValidateDefinition(taskName, batchPath, workingDirectory, time, daysInterval, account, requireAccount: true);

        if (string.IsNullOrWhiteSpace(credentialValue))
        {
            throw new InvalidOperationException("Enter the Windows account password to register an unattended task.");
        }

        dynamic folder = GetRootFolder();
        dynamic definition = CreateConnectedService().NewTask(0);
        definition.RegistrationInfo.Description = "Runs Tableau Server Backup through the repository batch entry point.";
        definition.Settings.Enabled = true;
        definition.Settings.StartWhenAvailable = true;
        definition.Settings.MultipleInstances = TaskInstancesIgnoreNew;
        definition.Principal.UserId = account.Trim();
        definition.Principal.LogonType = TaskLogonStoredCredential;
        definition.Principal.RunLevel = 1;

        dynamic trigger = definition.Triggers.Create(TaskTriggerDaily);
        trigger.StartBoundary = DateTime.Today.Add(time.ToTimeSpan()).ToString("s");
        trigger.DaysInterval = daysInterval;

        dynamic action = definition.Actions.Create(TaskActionExecute);
        action.Path = batchPath;
        action.WorkingDirectory = workingDirectory;

        try
        {
            folder.RegisterTaskDefinition(taskName, definition, TaskCreateOrUpdate, account.Trim(), credentialValue, TaskLogonStoredCredential, null);
        }
        finally
        {
            credentialValue = string.Empty;
        }
    }

    public void SetEnabled(string taskName, bool enabled)
    {
        dynamic folder = GetRootFolder();
        dynamic task = folder.GetTask(taskName);
        task.Enabled = enabled;
    }

    public void Remove(string taskName)
    {
        dynamic folder = GetRootFolder();
        folder.DeleteTask(taskName, 0);
    }

    private static dynamic GetRootFolder()
    {
        dynamic service = CreateConnectedService();
        return service.GetFolder("\\");
    }

    private static dynamic CreateConnectedService()
    {
        dynamic service = CreateService();
        service.Connect();
        return service;
    }

    private static dynamic CreateService()
    {
        var type = Type.GetTypeFromProgID("Schedule.Service")
                   ?? throw new PlatformNotSupportedException("Windows Task Scheduler is not available on this computer.");
        return Activator.CreateInstance(type)
               ?? throw new PlatformNotSupportedException("Windows Task Scheduler could not be started.");
    }

    private static void ValidateDefinition(string taskName, string batchPath, string workingDirectory, TimeOnly time, int daysInterval, string account, bool requireAccount)
    {
        if (string.IsNullOrWhiteSpace(taskName))
        {
            throw new InvalidOperationException("Task name is required.");
        }

        if (!File.Exists(batchPath))
        {
            throw new FileNotFoundException("The backup batch file was not found.", batchPath);
        }

        if (!Directory.Exists(workingDirectory))
        {
            throw new DirectoryNotFoundException($"The project folder was not found: {workingDirectory}");
        }

        if (daysInterval is < 1 or > 31)
        {
            throw new InvalidOperationException("Days interval must be between 1 and 31.");
        }

        if (requireAccount && string.IsNullOrWhiteSpace(account))
        {
            throw new InvalidOperationException("Windows task account is required.");
        }
    }

    private static string MapState(int state) => state switch
    {
        1 => "Disabled",
        2 => "Queued",
        3 => "Ready",
        4 => "Running",
        _ => "Unknown"
    };
}
