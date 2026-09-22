# false path for trigger
set_false_path -from {run_state_125_reg[*]} -to {trigger_500MHz:e_trigger|run_state_fast[*]}
set_false_path -from {trig_buffer_125[*]} -to {trig_buffer_125_reg[*]}
set_false_path -from {trigger_500MHz:e_trigger|trig_timestamp_save[*][*]} -to {trigger_500MHz:e_trigger|trig_ts_final[*][*]}
set_false_path -from {fe_block_v2:e_fe_block|feb_reg_mapping:e_reg_mapping|o_shutdown} -to {*}
set_false_path -from {trigger_500MHz:e_trigger|trig_buffer_125[*]} -to {trigger_500MHz:e_trigger|trig_buffer_125_reg[*]}
set_false_path -from {trigger_500MHz:e_trigger|Trig_TTL_prev[*]} -to {trigger_500MHz:e_trigger|trig_timestamp_save[*][*]}
set_false_path -from {debouncer:db2|o_q[*]} -to {trigger_500MHz:e_trigger|*};