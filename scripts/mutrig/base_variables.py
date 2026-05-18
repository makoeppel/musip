#
# Global Variables for common code, to be overridden by subdetector config
#

#Test mode flag, to be set to True for testing without actual hardware access
TEST_MODE = False


path_commands = "/Equipment/XXX/Commands"
path_asicsettings = "/Equipment/XXX/Settings/ASICs"
path_variables = "/Equipment/XXX/Variables"
path_links_settings = "/Equipment/LinksXXX/Settings"
bank_prefix = "XX"


path_hv = "/Equipment/HV"
path_lv = "/Equipment/TDK"


def check_defined():
    assert (path_commands != "/Equipment/XXX/Commands"), f"ODB variables for scan not set, make sure to import specialization module for subsystem in your main script"
