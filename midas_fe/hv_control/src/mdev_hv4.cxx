/********************************************************************\

  Name:         mdev_hv4.cxx
  Created by:   Stefan Ritt

  Contents:     MIDAS device drivers class for 4-channal HV boards

\********************************************************************/

#include <iostream>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netdb.h>

#include "midas.h"
#include "odbxx.h"

#include "mdev_hv4.h"

#include <cmath>

void mdev_hv4::add_card(int address, std::vector<std::string> names, float voltage_limit, float current_limit) {
   if (m_current_submaster.empty())
      mthrow("mdev_hv4::add_card called without a call to mdev_hv4::set_submaster()");

   auto card = new hv4_card(m_current_submaster, m_current_pwd, address);
   m_card.push_back(*card);
   for (size_t i=0 ; i<4 ; i++) {
      m_voltage_limit.push_back(voltage_limit);
      m_current_limit.push_back(current_limit);

      if (i >= names.size())
         m_names.push_back("CH" + std::to_string(m_length+i));
      else
         m_names.push_back(names[i]);

      m_mscb_address.push_back(m_current_submaster + ":" +
         std::to_string(address) + "-" +
         std::to_string(i));

      m_group.push_back(m_group_flag);
      m_group_flag = false;
   }
   delete card;

   m_length += 4;
}

void mdev_hv4::odb_setup(void) {
   // HV4 settings in ODB
   midas::odb settings = {
           { "Enabled",            true },
           { "Grid display",       true },
           { "Display",            "#, Names, Board, Output On, Demand, Voltage, Voltage limit, Current, Current limit" },
           { "Editable",           "Demand, Output On" },
           { "Format Current",     "%f1"},
           { "Unit Demand",        "V"},
           { "Unit Voltage",       "V"},
           { "Unit Voltage limit", "V"},
           { "Unit Current",       "uA"},
           { "Unit Current limit", "uA"},

           { "Output On",          false},
           { "Voltage limit",      0.f},
           { "Current limit",      0.f},
           { "Names",              std::string(31, '\0')},
           { "Board",              std::string(31, '\0')},
           { "MSCB",               std::string(31, '\0')},
           { "Group",              false}
   };
   settings.connect("/Equipment/" + m_equipment_name + "/Settings");
   m_settings.connect("/Equipment/" + m_equipment_name + "/Settings");

   // resize ODB arrays if necessary
   m_settings["Enabled"].resize(m_length, true);
   m_settings["Group"].resize(m_length);
   m_settings["Names"].resize(m_length);
   m_settings["Board"].resize(m_length);
   m_settings["MSCB"].resize(m_length);
   m_settings["Output On"].resize(m_length);
   m_settings["Voltage limit"].resize(m_length);
   m_settings["Current limit"].resize(m_length);

   // add info from add_card() calls
   m_settings["Names"] = m_names;
   m_settings["Group"] = m_group;
   m_settings["MSCB"] = m_mscb_address;
   m_settings["Voltage limit"] = m_voltage_limit;
   m_settings["Current limit"] = m_current_limit;

   // HV4 variables in ODB
   midas::odb variables = {
           { "Demand", 0.f},
           { "Voltage", 0.f},
           { "Current", 0.f},
   };
   variables.connect("/Equipment/" + m_equipment_name + "/Variables");
   m_variables.connect("/Equipment/" + m_equipment_name + "/Variables");
   m_variables["Demand"].resize(m_length);
   m_variables["Voltage"].resize(m_length);
   m_variables["Current"].resize(m_length);
}

void mdev_hv4::init(void) {

   mscb_set_max_retry(1);

   int n=0;
   for (hv4_card &card : m_card) {

      if (!m_settings["Enabled"][n]) {
         for (int i=0 ; i<4 ; i++,n++) {
            m_variables["Demand"][n]  = (float) ss_nan();
            m_variables["Voltage"][n] = (float) ss_nan();
            m_variables["Current"][n] = (float) ss_nan();
         }
         continue;
      }

      try {

         card.m_mscb = new midas::mscb(card.m_submaster, card.m_address, card.m_pwd);

      } catch (mexception &e) {
         std::string s = "Cannot connect to HV4 device \"" + card.m_submaster + ":" +
                         std::to_string(card.m_address) + "\"";
         for (int i=0 ; i<4 ; i++,n++) {
            m_variables["Demand"][n]  = (float) ss_nan();
            m_variables["Voltage"][n] = (float) ss_nan();
            m_variables["Current"][n] = (float) ss_nan();
         }
         mthrow1(s);
      }

      // set HVMax
      (*card.m_mscb)["HVMax"] = (float) m_voltage_limit[n];

      // set board name to [P|S|T]##
      for (int i=0 ; i<4 ; i++) {
         if (card.m_address < 23)
            m_settings["Board"][n+i] = std::string("P") + std::to_string(card.m_address) + "-" + std::to_string(i+1);
         else if (card.m_address < 38)
            m_settings["Board"][n+i] = std::string("S") + std::to_string(card.m_address) + "-" + std::to_string(i+1);
         else if (card.m_address < 66)
            m_settings["Board"][n+i] = std::string("T") + std::to_string(card.m_address) + "-" + std::to_string(i+1);
         else
            m_settings["Board"][n+i] = std::string("X") + std::to_string(card.m_address) + "-" + std::to_string(i+1);
      }

      // read all values
      for (int i=0 ; i<4 ; i++,n++) {
         m_demand_mirror.push_back((*(card.m_mscb))["HV"]);
         m_variables["Demand"][n] = m_demand_mirror[n];

         m_output_on_mirror.push_back((*card.m_mscb)[card.m_mscb->idx("On0")+i]);
         m_settings["Output On"][n] = m_output_on_mirror[n];

         m_variables["Voltage"][n] = (float) (*card.m_mscb)["HVMeas"];
         m_variables["Current"][n] = (float) (*card.m_mscb)[card.m_mscb->idx("I0")+i];
      }
   }

   // install callbacks
   m_settings["Output On"].watch([this](midas::odb &o) {
      // set output state on or off
      for (int i = 0; i < m_length; i++) {
         if (!m_settings["Enabled"][i])
            continue;

         bool b = o[i];
         if (b != m_output_on_mirror[i]) {
            m_output_on_mirror[i] = b;
            auto m = m_card[i / 4].m_mscb;
            (*m)[m->idx("On0") + (i % 4)] = (uint8_t) b;
         }
      }
   });

   m_variables["Demand"].watch([this](midas::odb &o) {
      // set demand voltage
      for (int i = 0; i < m_length; i++) {
         if (!m_settings["Enabled"][i])
            continue;

         float f = o[i];

         // check for voltage limit
         if (m_voltage_limit[i] > 0 && f > m_voltage_limit[i]) {
            cm_msg(MERROR, "mdev_hv4",
                   "Demand voltage %1.2lfV exceeds voltage limit of %1.2lfV for channel \"%s\" (index %d)",
                   f, m_voltage_limit[i], m_names[i].c_str(), i);
            f = m_voltage_limit[i];
         }

         // only write if different from mirror
         if (f != m_demand_mirror[i]) {
            m_demand_mirror[i] = f;
            (*(m_card[i / 4].m_mscb))["HV"] = f;
            printf("Write %1.3lf to %s\n", f, m_settings["Names"][i].s().c_str());
            // std::cout << *(m_card[i/4].m_mscb) << std::endl;
         }
      }
   });

}

void mdev_hv4::exit(void) {
}

/*------------------------------------------------------------------*/

void mdev_hv4::loop(void) {
   static DWORD last_time_measured = 0;

   // read values once per second
   if (ss_millitime() - last_time_measured > 1000) {
      int status = MSCB_SUCCESS;
      for (int i = 0; i < m_length; i++) {
         cm_yield(0);
         if (!m_settings["Enabled"][i])
            continue;

         auto m = m_card[i/4].m_mscb;
         if (i % 4 == 0)
            status = m->read_range();

         if (status != MSCB_SUCCESS) {
            m_demand_mirror[i] = (float)ss_nan();
            m_variables["Demand"][i] = m_demand_mirror[i];

            m_output_on_mirror[i] = false;
            m_settings["Output On"][i] = m_output_on_mirror[i];

            m_variables["Voltage"][i] = (float)ss_nan();
            m_variables["Current"][i] = (float)ss_nan();

            std::string s = "Communication error with \"" +
                    m->get_submaster() + ":" +
                    std::to_string(m->get_node_address()) + "\"";
            mthrow1(s);
         } else {
            m_demand_mirror[i] = (*m)["HV"];
            m_variables["Demand"][i] = m_demand_mirror[i];

            m_output_on_mirror[i] = (bool) (*m)[m->idx("On0") + (i % 4)];
            m_settings["Output On"][i] = m_output_on_mirror[i];

            float f = (*m)["HVMeas"];
            f = std::round(f * 100) / 100;
            if (!m_output_on_mirror[i])
               f = 0;
            m_variables["Voltage"][i] = f;
            m_variables["Current"][i] = (float) (*m)[m->idx("I0") + (i % 4)];
         }
      }
      last_time_measured = ss_millitime();
   }
}

/*------------------------------------------------------------------*/

int mdev_hv4::read_event(char *pevent, int off) {
   float *pdata;

   // init bank structure
   bk_init32a(pevent);

   // create a bank with measured voltage values
   bk_create(pevent, "SVOL", TID_FLOAT, (void **)&pdata);
   for (int i = 0; i < m_length; i++)
      *pdata++ = m_variables["Voltage"][i];
   bk_close(pevent, pdata);

   // create a bank with measured current values
   bk_create(pevent, "SCUR", TID_FLOAT, (void **)&pdata);
   for (int i = 0; i < m_length; i++)
      *pdata++ = m_variables["Current"][i];
   bk_close(pevent, pdata);

   return bk_size(pevent);
}
