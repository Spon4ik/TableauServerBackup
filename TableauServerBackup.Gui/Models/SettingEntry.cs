using System.ComponentModel;
using System.Runtime.CompilerServices;

namespace TableauServerBackup.Gui.Models;

public sealed class SettingEntry : INotifyPropertyChanged
{
    private string _value = string.Empty;

    public SettingEntry(string environmentVariable, string label, string helpText, bool isBoolean = false)
    {
        EnvironmentVariable = environmentVariable;
        Label = label;
        HelpText = helpText;
        IsBoolean = isBoolean;
    }

    public string EnvironmentVariable { get; }
    public string Label { get; }
    public string HelpText { get; }
    public bool IsBoolean { get; }

    public string Value
    {
        get => _value;
        set
        {
            if (_value == value)
            {
                return;
            }

            _value = value;
            OnPropertyChanged();
            OnPropertyChanged(nameof(BooleanValue));
        }
    }

    public bool BooleanValue
    {
        get => Value.Equals("true", StringComparison.OrdinalIgnoreCase)
               || Value.Equals("1", StringComparison.OrdinalIgnoreCase)
               || Value.Equals("yes", StringComparison.OrdinalIgnoreCase)
               || Value.Equals("on", StringComparison.OrdinalIgnoreCase);
        set => Value = value ? "true" : "false";
    }

    public event PropertyChangedEventHandler? PropertyChanged;

    private void OnPropertyChanged([CallerMemberName] string? propertyName = null) =>
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
}
