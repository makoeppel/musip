# pixel tuning and masking

```bash
export MIDAS_PATH=/PathToMidas
export MIDAS_PYTHON_PATH=$MIDAS_PATH/python
export MUSIP_PATH=/PathToMusip
export SCRIPT_PATH=$MUSIP_PATH/scripts
PYTHONPATH=$PYTHONPATH:$MIDAS_PYTHON_PATH:$SCRIPT_PATH python3 -m midas.sequencer
```

Example:
```bash
mu3e@localhost:~/musip $ export /   
mu3e@localhost:~/musip $ export MIDAS_PATH=/home/mu3e/midas
mu3e@localhost:~/musip $ export MIDAS_PYTHON_PATH=$MIDAS_PATH/python
mu3e@localhost:~/musip $ echo $MIDAS_PYTHON_PATH
mu3e@localhost:~/musip $ export MUSIP_PATH=/home/mu3e/musip
mu3e@localhost:~/musip $ export SCRIPT_PATH=$MUSIP_PATH/scripts
mu3e@localhost:~/musip $ PYTHONPATH=$PYTHONPATH:$MIDAS_PYTHON_PATH:$SCRIPT_PATH python3 -m midas.sequencer
Starting PySequencer with base ODB directory of /PySequencer
Loading script /home/mu3e/online/online/userfiles/sequencer/pixels/python_qc/scripts/noise_scan.py ...
Running user's `define_params()` function
Script loaded successfully
```