/*
   mdevice_mscbhv4.h

   Defines class mdevice_mscbhv4 derived from class mdevice for
   MSCB Mu3e high voltage box.

   SR 13.04.2022
*/

class mdevice_mscbhv4: public mdevice {
   double mHvMax = -1;
public:
   mdevice_mscbhv4(std::string eq_name,
                   std::string dev_name,
                   std::string submaster,
                   std::string pwd = "") :
                      mdevice(eq_name, dev_name,
                              DF_HW_RAMP | DF_PRIO_DEVICE | DF_MULTITHREAD | DF_QUICKSTART | DF_POLL_DEMAND,
                              mscbhv4) {

      if (submaster.empty()) {
         cm_msg(MERROR, "mdevice_mscbhv4", "Device \"%s\" defined without submaster name", dev_name.c_str());
         return;
      }

      // create Settings/Devices in ODB
      midas::odb dev = {
              {"MSCB Device",    std::string(255, '\0')},
              {"MSCB Pwd",       std::string(31, '\0')},
              {"MSCB Debug",     (INT32) 0},
              {"MSCB Address",   (INT32) 0}
      };
      dev.connect("/Equipment/" + eq_name + "/Settings/Devices/" + dev_name);
      dev["MSCB Device"] = submaster;
      dev["MSCB Pwd"]    = pwd;
   }

   void set_hvmax(double hv_max)
   {
      mHvMax = hv_max;
   }

   void define_box(int address, std::vector<std::string> name, double hv_max = -1)
   {
      // count total number of input channels
      int chn_total = 0;
      for (int i=0 ; i <= mDevIndex ; i++)
         chn_total += mEq->driver[i].channels;

      mOdbDev["MSCB Address"][mEq->driver[mDevIndex].channels/4] = address;

      mOdbSettings.set_preserve_string_size(true);
      if (chn_total == 0)
         mOdbSettings["Names"][0] = std::string(31, '\0');

      int n_channels = name.size();

      for (int i=0 ; i<n_channels ; i++) {
         if (i >= (int) name.size() || name[i] == std::string("")) {
            // put some default name, names must be unique
            int ch = mEq->driver[mDevIndex].channels + i;
            mOdbSettings["Names"][chn_total + i] = mDevName + "%CH " + std::to_string(ch) + " " +
                    std::to_string(address) + "-" + std::to_string(i);
         } else
            mOdbSettings["Names"][chn_total + i] = name[i];

         mName.push_back(name[i]);

         if (hv_max != -1)
            mOdbSettings["Voltage Limit"][chn_total + i] = (float)hv_max;
         else if (mHvMax != -1)
            mOdbSettings["Voltage Limit"][chn_total + i] = (float)mHvMax;
      }

      mEq->driver[mDevIndex].channels += n_channels;
      mNchannels += n_channels;
   }

   void define_history_panel(std::string panelName, std::string varName)
   {
      std::vector<std::string> vars;

      int chn_first = 0;
      for (int i=0 ; i < mDevIndex ; i++)
         chn_first += mEq->driver[i].channels;


      for (int i=chn_first ; i<chn_first + mEq->driver[mDevIndex].channels ; i++) {
         std::string name =  mOdbSettings["Names"][i];
         vars.push_back(mEq->name + std::string(":") + name + std::string(" ") + varName);
      }

      hs_define_panel(mEq->name, panelName.c_str(), vars);
   }

};
