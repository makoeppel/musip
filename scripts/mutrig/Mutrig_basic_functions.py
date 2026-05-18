import mutrig.base_variables as cfg

##################################################
# Mutrig paths for ODB access of channels and asics
##################################################
def Get_asic_odb_path(setting, index=None):
    if index is not None:
        return f"{cfg.path_settings}/ASICs/TDCs/{setting}[{index}]"
    else:
        return f"{cfg.path_settings}/ASICs/TDCs/{setting}"

def Get_channel_odb_path(setting, index=None):
    if index is not None:
        return f"{cfg.path_settings}/ASICs/Channels/{setting}[{index}]"
    else:
        return f"{cfg.path_settings}/ASICs/Channels/{setting}"

##################################################
# Standard Mutrig ASIC commands
##################################################
def Configure_all_asics(client):
    client.odb_set(f"{cfg.path_commands}/MutrigConfig", 1)
    while client.odb_get(f"{cfg.path_commands}/MutrigConfig") < 1:
        time.sleep(0.1)

def SetTestPulse(client, enable=1):
    client.odb_set(f"{cfg.path_commands}/TestPulsesTDC", enable)


##################################################
# Standard Mutrig ASIC configuration
##################################################
def Mutrig_TorE_ASIC_configure(client):
    path = f"{cfg.path_settings}/ASICs"
    settings=client.odb_get(path)
    length_ch = len(settings['Channels']['cml'])
    length_asic = len(settings['TDCs']['dmon_select'])
    settings['Global']['tx_mode']=0
    settings['Channels']['cml']=[8]*length_ch;
    settings['Channels']['cml_sc']=[0]*length_ch;
    settings['Channels']['tdctest_n']=[1]*length_ch;
    settings['Channels']['recv_all']=[1]*length_ch;
    settings['TDCs']['dmon_select']=[-1]*length_asic;
    
    settings=client.odb_set(path,settings);
    SetTestPulse(client, enable=0);
    Configure_all_asics(client);

def Mutrig_TandE_ASIC_configure(client):
    path = f"{cfg.path_settings}/ASICs"
    settings=client.odb_get(path)
    length_ch = len(settings['Channels']['cml'])
    length_asic = len(settings['TDCs']['dmon_select'])
    settings['Global']['tx_mode']=0
    settings['Channels']['cml']=[8]*length_ch;
    settings['Channels']['cml_sc']=[0]*length_ch;
    settings['Channels']['tdctest_n']=[1]*length_ch;
    settings['Channels']['recv_all']=[0]*length_ch;
    settings['TDCs']['dmon_select']=[-1]*length_asic;
    
    settings=client.odb_set(path,settings);
    SetTestPulse(client, enable=0);
    Configure_all_asics(client);

def Mutrig_Inject_ASIC_configure(client):
    path = f"{cfg.path_settings}/ASICs"
    settings=client.odb_get(path)
    length_ch = len(settings['Channels']['cml'])
    length_asic = len(settings['TDCs']['dmon_select'])
    settings['Global']['tx_mode']=0
    settings['Channels']['cml']=[0]*length_ch;
    settings['Channels']['cml_sc']=[1]*length_ch;
    settings['Channels']['tdctest_n']=[0]*length_ch;
    settings['Channels']['recv_all']=[1]*length_ch;
    settings['TDCs']['dmon_select']=[-1]*length_asic;
    
    settings=client.odb_set(path,settings);
    SetTestPulse(client, enable=1);
    Configure_all_asics(client);
    #Empirically found that reconfiguring cml back to 8, then 0 allows to recover most channels
    settings['Channels']['cml']=[8]*length_ch;
    settings=client.odb_set(path,settings);
    Configure_all_asics(client);
    settings['Channels']['cml']=[0]*length_ch;
    settings=client.odb_set(path,settings);
    Configure_all_asics(client);
##################################################

#Store ebranch, recover ebranch functions
def Get_tth(client):
    previous_threshold = {}
    path_threshold = Get_channel_odb_path("tthresh")
    client.msg(f"Reading previous T-threshold settings from {path_threshold}")
    previous_threshold = client.odb_get(path_threshold)
    return previous_threshold

def Set_tth(client,previous_threshold):
    path_threshold = Get_channel_odb_path("tthresh")
    client.msg(f"Reading previous T-threshold settings from {path_threshold}")
    client.odb_set(path_threshold,previous_threshold)

def Get_eth(client):
    previous_threshold = {}
    path_threshold = Get_channel_odb_path("ethresh")
    client.msg(f"Reading previous E-threshold settings from {path_threshold}")
    previous_threshold = client.odb_get(path_threshold)
    return previous_threshold

def Set_eth(client,previous_threshold):
    path_threshold = Get_channel_odb_path("ethresh")
    client.msg(f"Reading previous E-threshold settings from {path_threshold}")
    client.odb_set(path_threshold,previous_threshold)

def Store_Settings(client):
    settings=client.odb_get(f"{cfg.path_settings}")
    return settings

def Restore_Settings(client,settings):
    settings=client.odb_set(f"{cfg.path_settings}",settings)
    Configure_all_asics(client)

def Get_tth_offsets(client):
    path = Get_channel_odb_path("tthresh_offset")
    return client.odb_get(path)

def Set_tth_offsets(client, offsets):
    path = Get_channel_odb_path("tthresh_offset")
    client.msg(f"Setting T-threshold offsets at {path}")
    client.odb_set(path, offsets)