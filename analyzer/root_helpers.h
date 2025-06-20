#ifndef ROOTHELPERS_H
#define ROOTHELPERS_H

#include "TDirectory.h"

template <typename T>
TDirectory* make_or_get_dir(const T* name, TDirectory* rootdir = gDirectory) {
    if(rootdir->GetDirectory(name)) {
        // printf("Found directory %s\n",name);
        return rootdir->GetDirectory(name);
    }
    else {
        // printf("Creating directory %s\n",name);
        return rootdir->mkdir(name);
    }
};

#endif
