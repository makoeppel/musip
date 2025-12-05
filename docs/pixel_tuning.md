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

# tdac writing
Tdac writing for a chip would work like this:
write 32 bit words, 4* 8bit tdac in each word
order:
    col 0 -> 255, starting with col 0, physical col addr.
    row 0 -> row 255 for each col, starting with row0, physical row addr.

    example:
    start with col 0 ..
    (32 bit)  : [8 bit tdac, 8 bit tdac, 8 bit tdac, 8 bit tdac]
    word 0    : [row 3     , row 2     , row 1     , row 0     ]
    word 1    : [row 7     , row 6     , row 5     , row 4     ]
    word 2    : [row 11    , row 10    , row 9     , row 8     ]
    ...
    word 63   : [row 255   , row 254   , row253    , row 252   ]
    now col 1 ..
    word 64   : [row 3     , row 2     , row 1     , row 0     ]
    ...
