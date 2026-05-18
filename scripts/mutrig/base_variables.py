#
# Global Variables for common code, to be overridden by subdetector config
#

path_commands = "/Equipment/XXX/Commands"
path_settings = "/Equipment/XXX/Settings"
path_asicsettings = "/Equipment/XXX/Settings/ASICs"
path_variables = "/Equipment/XXX/Variables"
path_links_settings = "/Equipment/LinksXXX/Settings"

path_hv = "/Equipment/HV"
path_lv = "/Equipment/TDK"



path_hv = "/Equipment/HV"
path_lv = "/Equipment/TDK"


def check_defined():
    assert (path_commands != "/Equipment/XXX/Commands"), f"ODB variables for scan not set, make sure to import specialization module for subsystem in your main script"
