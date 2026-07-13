using System.IO;

namespace TableauServerBackup.Gui.Services;

public sealed class TaskNamePreferenceService
{
    private static readonly string PreferencePath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "TableauServerBackup",
        "last-scheduled-task-name.txt");

    public string Load()
    {
        try
        {
            return File.Exists(PreferencePath) ? File.ReadAllText(PreferencePath).Trim() : string.Empty;
        }
        catch (IOException)
        {
            return string.Empty;
        }
        catch (UnauthorizedAccessException)
        {
            return string.Empty;
        }
    }

    public void Save(string taskName)
    {
        if (string.IsNullOrWhiteSpace(taskName))
        {
            return;
        }

        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(PreferencePath)!);
            File.WriteAllText(PreferencePath, taskName.Trim());
        }
        catch (IOException)
        {
            // Remembering a convenience value must never prevent task administration.
        }
        catch (UnauthorizedAccessException)
        {
            // Remembering a convenience value must never prevent task administration.
        }
    }
}
