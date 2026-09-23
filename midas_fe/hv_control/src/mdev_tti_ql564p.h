/********************************************************************\

  Name:         mdev_tti_ql564p.h
  Contents:     MIDAS device driver for TTI QL564P supplies

\********************************************************************/

#ifndef MDEV_TTI_QL564P_H
#define MDEV_TTI_QL564P_H

#include <string>
#include <vector>

#include "mdev.h"

class tti_ql564p_card {
   public:
    std::string m_host;
    int m_port;
    int m_socket;

    tti_ql564p_card(std::string host) : m_host(host), m_port(9221), m_socket(-1) {}
    ~tti_ql564p_card();

    void connect();
    void close();
    void command(const std::string& command);
    std::string query(const std::string& command);

    void write_voltage(int channel, float voltage);
    float read_demand(int channel);
    float read_voltage(int channel);
    void write_output(int channel, bool enabled);
    bool read_output(int channel);
    void write_current_limit(int channel, float current);
    float read_current_limit(int channel);
    float read_current(int channel);
    void write_voltage_limit(int channel, float voltage);
    float read_voltage_limit(int channel);
};

class mdev_tti_ql564p : public mdev {
   private:
    static constexpr int channels_per_card = 1;

    midas::odb m_settings;
    midas::odb m_variables;
    int m_length;
    std::string m_current_host;

    std::vector<std::string> m_names;
    std::vector<bool> m_group;
    std::vector<float> m_voltage_limit;
    std::vector<float> m_current_limit;
    std::vector<float> m_demand_mirror;
    std::vector<bool> m_output_on_mirror;
    std::vector<tti_ql564p_card> m_card;

    void read_channel(int index);

   public:
    explicit mdev_tti_ql564p(std::string equipment_name)
        : mdev(equipment_name), m_length(0) {}
    ~mdev_tti_ql564p() override = default;

    void set_host(std::string host);
    void add_card(std::vector<std::string> names = {}, float voltage_limit = 56,
                  float current_limit = 2);

    void odb_setup(void) override;
    void init(void) override;
    void exit(void) override;
    void loop(void) override;
    int read_event(char* pevent, int off) override;
};

#endif  // MDEV_TTI_QL564P_H