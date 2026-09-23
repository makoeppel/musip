/********************************************************************\

  Name:         mdev_tti_ql564p.cxx
  Contents:     MIDAS device driver for TTI QL564P supplies

\********************************************************************/

#include <cerrno>
#include <cmath>
#include <cstring>
#include <iostream>
#include <netdb.h>
#include <poll.h>
#include <sstream>
#include <sys/socket.h>
#include <unistd.h>

#include <stdexcept>
#include <utility>

#include "midas.h"
#include "odbxx.h"
#include "mdev_tti_ql564p.h"

namespace {
constexpr int read_timeout_ms = 2000;
constexpr size_t max_reply_size = 1024;
}

tti_ql564p_card::~tti_ql564p_card() { close(); }

void tti_ql564p_card::close() {
   if (m_socket >= 0) {
      ::close(m_socket);
      m_socket = -1;
   }
}

void tti_ql564p_card::connect() {
   close();

   struct addrinfo hints {};
   hints.ai_family = AF_UNSPEC;
   hints.ai_socktype = SOCK_STREAM;
   struct addrinfo* result = nullptr;
   const std::string port = std::to_string(m_port);
   int status = getaddrinfo(m_host.c_str(), port.c_str(), &hints, &result);
   if (status != 0)
      throw std::runtime_error("Cannot resolve " + m_host + ":" + port + ": " +
                               gai_strerror(status));

   for (struct addrinfo* address = result; address != nullptr; address = address->ai_next) {
      m_socket = socket(address->ai_family, address->ai_socktype, address->ai_protocol);
      if (m_socket < 0)
         continue;
      if (::connect(m_socket, address->ai_addr, address->ai_addrlen) == 0)
         break;
      close();
   }
   freeaddrinfo(result);

   if (m_socket < 0)
      throw std::runtime_error("Cannot connect to " + m_host + ":" + port + ": " +
                               std::strerror(errno));
}

void tti_ql564p_card::command(const std::string& command_string) {
   if (m_socket < 0)
      throw std::runtime_error("TTI device is not connected");

   std::string message = command_string + "\n";
   size_t sent = 0;
   while (sent < message.size()) {
      ssize_t count = send(m_socket, message.data() + sent, message.size() - sent, MSG_NOSIGNAL);
      if (count <= 0)
         throw std::runtime_error("Failed to send command to " + m_host + ": " +
                                  std::strerror(errno));
      sent += static_cast<size_t>(count);
   }
}

std::string tti_ql564p_card::query(const std::string& command_string) {
   command(command_string);

   std::string reply;
   char buffer[128];
   while (reply.size() < max_reply_size) {
      struct pollfd descriptor {m_socket, POLLIN, 0};
      int status = poll(&descriptor, 1, read_timeout_ms);
      if (status <= 0)
         throw std::runtime_error("Timeout reading response from " + m_host);

      ssize_t count = recv(m_socket, buffer, sizeof(buffer), 0);
      if (count <= 0)
         throw std::runtime_error("Failed to read response from " + m_host + ": " +
                                  std::strerror(errno));
      reply.append(buffer, static_cast<size_t>(count));
      if (reply.find('\n') != std::string::npos)
         break;
   }
   return reply;
}

namespace {
float parse_number(const std::string& reply) {
   std::istringstream stream(reply);
   std::string token;
   float value = 0;
   while (stream >> token) {
      if (!token.empty() && token.back() == 'V')
         token.pop_back();
      try {
         value = std::stof(token);
      } catch (const std::invalid_argument&) {
      }
   }
   return value;
}
}

void tti_ql564p_card::write_voltage(int channel, float voltage) {
   command("V" + std::to_string(channel) + " " + std::to_string(voltage));
}

float tti_ql564p_card::read_demand(int channel) {
   return parse_number(query("V" + std::to_string(channel) + "?"));
}

float tti_ql564p_card::read_voltage(int channel) {
   return parse_number(query("V" + std::to_string(channel) + "O?"));
}

void tti_ql564p_card::write_output(int channel, bool enabled) {
   command("OP" + std::to_string(channel) + " " + (enabled ? "1" : "0"));
}

bool tti_ql564p_card::read_output(int channel) {
   return parse_number(query("OP" + std::to_string(channel) + "?")) != 0;
}

void tti_ql564p_card::write_current_limit(int channel, float current) {
   command("I" + std::to_string(channel) + " " + std::to_string(current));
}

float tti_ql564p_card::read_current_limit(int channel) {
   return parse_number(query("I" + std::to_string(channel) + "?"));
}

float tti_ql564p_card::read_current(int channel) {
   return parse_number(query("I" + std::to_string(channel) + "O?"));
}

void tti_ql564p_card::write_voltage_limit(int channel, float voltage) {
   command("OVP" + std::to_string(channel) + " " + std::to_string(voltage));
}

float tti_ql564p_card::read_voltage_limit(int channel) {
   return parse_number(query("OVP" + std::to_string(channel) + "?"));
}

void mdev_tti_ql564p::set_host(std::string host) {
   m_current_host = std::move(host);
}

void mdev_tti_ql564p::add_card(std::vector<std::string> names, float voltage_limit,
                               float current_limit) {
   if (m_current_host.empty())
      mthrow("mdev_tti_ql564p::add_card called without a call to set_host()");

   m_card.emplace_back(m_current_host);
   for (int channel = 0; channel < channels_per_card; channel++) {
      m_names.push_back(channel < static_cast<int>(names.size())
                            ? names[channel]
                            : "CH" + std::to_string(m_length + channel));
      m_group.push_back(false);
      m_voltage_limit.push_back(voltage_limit);
      m_current_limit.push_back(current_limit);
   }
   m_length += channels_per_card;
}

void mdev_tti_ql564p::odb_setup(void) {
   midas::odb settings = {
       {"Enabled", true},
       {"Grid display", true},
       {"Display", "#, Names, Output On, Demand, Voltage limit, Current limit"},
       {"Editable", "Demand, Output On, Voltage limit, Current limit"},
       {"Unit Demand", "V"},
       {"Unit Voltage limit", "V"},
       {"Unit Current limit", "A"},
       {"Output On", false},
       {"Voltage limit", 56.f},
       {"Current limit", 2.f},
       {"Names", std::string(31, '\0')},
       {"Group", false}};
   settings.connect("/Equipment/" + m_equipment_name + "/Settings");
   m_settings.connect("/Equipment/" + m_equipment_name + "/Settings");

   m_settings["Enabled"].resize(m_length, true);
   m_settings["Output On"].resize(m_length);
   m_settings["Voltage limit"].resize(m_length);
   m_settings["Current limit"].resize(m_length);
   m_settings["Names"].resize(m_length);
   m_settings["Group"].resize(m_length);
   m_settings["Names"] = m_names;
   m_settings["Group"] = m_group;
   m_settings["Voltage limit"] = m_voltage_limit;
   m_settings["Current limit"] = m_current_limit;

      midas::odb variables = {
         {"Demand", 0.f},
         {"Voltage", 0.f},
         {"Current", 0.f}};
   variables.connect("/Equipment/" + m_equipment_name + "/Variables");
   m_variables.connect("/Equipment/" + m_equipment_name + "/Variables");
   m_variables["Demand"].resize(m_length);
   m_variables["Voltage"].resize(m_length);
   m_variables["Current"].resize(m_length);
}

void mdev_tti_ql564p::read_channel(int index) {
   tti_ql564p_card& card = m_card[index / channels_per_card];
   int channel = index % channels_per_card + 1;

   m_demand_mirror[index] = card.read_demand(channel);
   m_output_on_mirror[index] = card.read_output(channel);
   m_variables["Demand"][index] = m_demand_mirror[index];
   m_settings["Output On"][index] = m_output_on_mirror[index];

   float voltage = card.read_voltage(channel);
   m_variables["Voltage"][index] = std::round(voltage * 100) / 100;
   m_variables["Current"][index] = card.read_current(channel);

   m_voltage_limit[index] = card.read_voltage_limit(channel);
   m_current_limit[index] = card.read_current_limit(channel);
   m_settings["Voltage limit"][index] = m_voltage_limit[index];
   m_settings["Current limit"][index] = m_current_limit[index];
}

void mdev_tti_ql564p::init(void) {
   m_demand_mirror.assign(m_length, 0.f);
   m_output_on_mirror.assign(m_length, false);

   for (size_t card_index = 0; card_index < m_card.size(); card_index++) {
      bool enabled = false;
      for (int channel = 0; channel < channels_per_card; channel++)
         enabled = enabled || m_settings["Enabled"][card_index * channels_per_card + channel];
      if (!enabled)
         continue;

      try {
         m_card[card_index].connect();
         for (int channel = 0; channel < channels_per_card; channel++) {
            int index = static_cast<int>(card_index) * channels_per_card + channel;
            if (!m_settings["Enabled"][index]) {
               m_variables["Demand"][index] = (float)ss_nan();
               m_variables["Voltage"][index] = (float)ss_nan();
               m_variables["Current"][index] = (float)ss_nan();
               continue;
            }
            read_channel(index);
         }
      } catch (const std::exception& error) {
         mthrow1("Cannot initialize TTI QL564P device \"" + m_card[card_index].m_host +
                 ":" + std::to_string(m_card[card_index].m_port) + "\": " + error.what());
      }
   }

   m_settings["Output On"].watch([this](midas::odb& values) {
      for (int index = 0; index < m_length; index++) {
         if (!m_settings["Enabled"][index] || static_cast<bool>(values[index]) ==
                                                   m_output_on_mirror[index])
            continue;
          m_card[index / channels_per_card].write_output(
             index % channels_per_card + 1, static_cast<bool>(values[index]));
         m_output_on_mirror[index] = values[index];
      }
   });
   m_variables["Demand"].watch([this](midas::odb& values) {
      for (int index = 0; index < m_length; index++) {
         if (!m_settings["Enabled"][index])
            continue;
         float demand = values[index];
         if (m_voltage_limit[index] > 0 && demand > m_voltage_limit[index])
            demand = m_voltage_limit[index];
         if (demand != m_demand_mirror[index]) {
            m_card[index / channels_per_card].write_voltage(index % channels_per_card + 1, demand);
            m_demand_mirror[index] = demand;
            values[index] = demand;
         }
      }
   });
   m_settings["Current limit"].watch([this](midas::odb& values) {
      for (int index = 0; index < m_length; index++) {
         if (m_settings["Enabled"][index])
            m_card[index / channels_per_card].write_current_limit(index % channels_per_card + 1,
                                                                  values[index]);
      }
   });
   m_settings["Voltage limit"].watch([this](midas::odb& values) {
      for (int index = 0; index < m_length; index++) {
         if (m_settings["Enabled"][index]) {
            m_voltage_limit[index] = values[index];
            m_card[index / channels_per_card].write_voltage_limit(index % channels_per_card + 1,
                                                                  values[index]);
         }
      }
   });
}

void mdev_tti_ql564p::exit(void) {
   for (tti_ql564p_card& card : m_card)
      card.close();
}

void mdev_tti_ql564p::loop(void) {
   static DWORD last_time_measured = 0;
   if (ss_millitime() - last_time_measured <= 1000)
      return;

   for (int index = 0; index < m_length; index++) {
      cm_yield(0);
      if (!m_settings["Enabled"][index]) {
         m_variables["Demand"][index] = (float)ss_nan();
         m_variables["Voltage"][index] = (float)ss_nan();
         m_variables["Current"][index] = (float)ss_nan();
         continue;
      }

      try {
         read_channel(index);
      } catch (const std::exception& error) {
         m_variables["Demand"][index] = (float)ss_nan();
         m_variables["Voltage"][index] = (float)ss_nan();
         m_variables["Current"][index] = (float)ss_nan();
         throw std::runtime_error("Readback failed for TTI QL564P device \"" +
                                  m_card[index / channels_per_card].m_host + ":" +
                                  std::to_string(m_card[index / channels_per_card].m_port) +
                                  ": " + error.what());
      }
   }
   last_time_measured = ss_millitime();
}

int mdev_tti_ql564p::read_event(char* pevent, int off) {
   (void)off;
   float* data;

   bk_init32a(pevent);

   bk_create(pevent, "SVOL", TID_FLOAT, (void**)&data);
   for (int index = 0; index < m_length; index++)
      *data++ = m_variables["Voltage"][index];
   bk_close(pevent, data);

   bk_create(pevent, "SCUR", TID_FLOAT, (void**)&data);
   for (int index = 0; index < m_length; index++)
      *data++ = m_variables["Current"][index];
   bk_close(pevent, data);

   return bk_size(pevent);
}