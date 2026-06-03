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
polarity_inverted = "False"

path_hv = "/Equipment/HV"
path_lv = "/Equipment/TDK"

def Print():
    print("*** MuTRiG Scan setup variables ***")
    print(f"path_commands       = {path_commands}")
    print(f"path_asicsettings   = {path_asicsettings}")
    print(f"path_variables      = {path_variables}")
    print(f"path_links_settings = {path_links_settings}")
    print(f"bank_prefix         = {bank_prefix}")
    print(f"polarity_inverted   = {polarity_inverted}")
    print("*************************************")


    print 
def check_defined():
    assert (path_commands != "/Equipment/XXX/Commands"), f"ODB variables for scan not set, make sure to import specialization module for subsystem in your main script"
