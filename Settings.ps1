# Configure the variables below that will be used in the script
$HAToken = "<HAToken>" # Example: eyJ0eXAiOiJKV1...
$HAUrl = "<HAUrl>" # Example: https://yourha.duckdns.org
$entityID = "input_boolean.homeoffice_monitor" # The entity ID of the home office external monitor in Home Assistant
$builtInMonitor = "<SERIAL>" # The serial number of the built-in monitor of the laptop
$externalMonitor = "<SERIAL>" # The serial number of the external monitor
$Interval = 60 # The interval in seconds to check the monitor status