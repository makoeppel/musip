/********************************************************************\

  Name:         mdev_hv4.h
  Created by:   Stefan Ritt

  Contents:     MIDAS device drivers class for 4-channel HV boards

\********************************************************************/

#ifndef MDEV_HV4_H
#define MDEV_HV4_H

#include "odbxx.h"
#include "mscbxx.h"
#include "mdev.h"

class hv4_card {
public:
   std::string  m_submaster;
   std::string  m_pwd;
   int          m_address;
   midas::mscb* m_mscb;

public:
   hv4_card(std::string s, std::string pwd, int a) : m_submaster(s), m_pwd(pwd), m_address(a) {};
};

class mdev_hv4 : public mdev {

private:
   midas::odb m_settings;
   midas::odb m_variables;
   int        m_length;

   std::string m_current_submaster;
   std::string m_current_pwd;
   bool        m_group_flag;

   std::vector<std::string> m_names;
   std::vector<std::string> m_mscb_address;
   std::vector<bool>        m_group;
   std::vector<float>       m_voltage_limit;
   std::vector<float>       m_current_limit;

   std::vector<float>       m_demand_mirror;
   std::vector<bool>        m_output_on_mirror;

   std::vector<hv4_card>    m_card;

public:
   mdev_hv4(std::string equipment_name) : mdev(equipment_name), m_length(0), m_group_flag(false) {};
   ~mdev_hv4(void) {};

   void set_submaster(std::string s, std::string pwd = "") { m_current_submaster = s; m_current_pwd = pwd; };
   void add_card(int address, std::vector<std::string> n = {}, float voltage_limit = 120, float current_limit = 1000);
   void start_new_group() { m_group_flag = true; }

   void odb_setup(void);
   void init(void);
   void exit(void);
   void loop(void);

   int read_event(char *pevent, int off);

};

#endif // MDEV_HV4_H
