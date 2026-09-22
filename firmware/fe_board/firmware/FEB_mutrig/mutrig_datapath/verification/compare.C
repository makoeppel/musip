#include <boost/algorithm/string/predicate.hpp>
#include <boost/lexical_cast.hpp>

struct hit{
    unsigned int asic,channel,tbh, tcc, tfine,ebh,ecc,efine,eflag;
    bool EtypeWritten;
    bool IsEmpty;
    hit(){EtypeWritten=false;IsEmpty=true;}
    bool compare(hit& other){
        if (other.tbh  != tbh  ) { /*printf("Mismatch in tbh\n");*/ return false; }
        if (other.tcc  != tcc  ) { /*printf("Mismatch in tcc\n");*/ return false; }
        if (other.tfine!= tfine) { /*printf("Mismatch in tfine\n")*/; return false; }
        if (other.eflag!= eflag) { /*printf("Mismatch in eflag\n");*/ return false; }
        if (EtypeWritten && (other.ebh  != ebh  )) { /*printf("Mismatch in ebh\n");*/ return false; }
        if (EtypeWritten && (other.ecc  != ecc  )) { /*printf("Mismatch in ecc\n");*/ return false; }
        if (EtypeWritten && (other.efine!= efine)) { /*printf("Mismatch in efine\n");*/ return false; }
        return true;
    }
};

void PrintHit(hit hit_ro,const char* prefix=""){
    printf("%sHit from ASIC %u:%u,\tTCC %4.4x\tTFINE %2.2x",prefix,hit_ro.asic,hit_ro.channel,hit_ro.tcc,hit_ro.tfine);
    if(hit_ro.EtypeWritten)
        printf("\tECC %4.4x\tEFINE %2.2x",hit_ro.ecc,hit_ro.efine);
    printf(" EFL %c\n",hit_ro.eflag?'y':'n');
}

hit PopFirstInTDC(std::list<hit>& list, unsigned int asic, unsigned int channel){
    int i=0;
    for(std::list<hit>::iterator ihit = list.begin(); ihit!=list.end();ihit++,i++){
        PrintHit(*ihit,"? ");
        if(ihit->asic==asic && ihit->channel==channel){
            //PrintHit(*ihit,"  ");
            printf("  ->found after %d\n",i);
            hit hit_ret=*ihit;
            list.erase(ihit);
            return hit_ret;
        }
    }
    return hit(); //return empty hit
}

void compare(){
//fill list of TDC hits
//--write(l, string'("#ASIC CH  TBH TCC  FineT EBH CCE  FineE 1"));
//                    0     0   0   7CBD 1F    0   52E0 0A    1
    cout<<"Parsing TDC data..."<<endl;
    int nExcluded_TDC=0;
    int nSkipped_TDC=0;
    std::list<hit> hits_TDC;
    {
        int nline=0;
        std::ifstream infile("TDC_data.txt");
        if (!infile.good()) {
            cout<<"File not readable"<<endl;
            return;
        }

        string line;
        // Looping
        std::map<unsigned int, hit> lasthit;
        while (std::getline(infile, line, '\n')) {
            hit newhit;
            newhit.IsEmpty=false;
            newhit.EtypeWritten=true;
            if (line == "") continue;
            if (line[line.size() - 1] == char(13))// removing DOS CR character
                line.erase(line.end() - 1, line.end());
            int status=sscanf(line.c_str(),"%u %u %x %x %x %x %x %x %x",&newhit.asic,&newhit.channel,&newhit.tbh,&newhit.tcc,&newhit.tfine,&newhit.ebh,&newhit.ecc,&newhit.efine,&newhit.eflag);
            if (status!=9){
                printf("Skipping line (%d) at %d: %s\n",status,nline,line.c_str());
                nSkipped_TDC++;
                continue;
            }
            if (!lasthit[newhit.asic*32+newhit.channel].IsEmpty && lasthit[newhit.asic*32+newhit.channel].compare(newhit)){
                printf("Skipping duplicate hit at line %d\t: %s\n",nline,line.c_str());
                nExcluded_TDC++;
                continue;
            }
            lasthit[32*newhit.asic+newhit.channel]=newhit;
            hits_TDC.push_back(newhit);
            nline++;
        }
    }
    int nParsed_TDC=hits_TDC.size();
    cout<<"Parsing readout data..."<<endl;
    int nSkipped_Readout=0;
    std::list<hit> hits_readout;
    {
        int nline=0;
        std::ifstream infile("readout_data.txt");
        if (!infile.good()) {
            cout<<"File not readable"<<endl;
            return;
        }
        //variables for data structure DRC
        bool in_frame=false;
        bool in_header=false;
        int last_frameID=-1;
        string line;
        // Looping
        hit thehit;
        while (std::getline(infile, line, '\n')) {
            hit newhit;
            if (line == "") continue;
            if (line[line.size() - 1] == char(13))// removing DOS CR character
                line.erase(line.end() - 1, line.end());
            //data structure DRC
            if (boost::starts_with(line, "Frame Header / Payload 1")){
                if(in_frame || in_header) {printf("DRC error: Unexpected Header 1 at line %d\n",nline); return;};
                in_frame=true;
                in_header=true;
            }else
            if (boost::starts_with(line, "Frame Header / Payload 2")){
                if(!in_frame || !in_header) {printf("DRC error: Unexpected Header 2 at line %d\n",nline); return;};
                in_header=false;
                unsigned int raw, tmp,fasyn,fID;
                if(sscanf(line.c_str(),"Frame Header / Payload 2	RAW %x	TS(LO)=%x	FSYN=%x	FID =%x",&raw,&tmp,&fasyn,&fID)!=4){
                    printf("Skipping line (%d) %s\n",nline,line.c_str());
                    nSkipped_Readout++;
                    continue;
                };
                if(last_frameID>=0 && fID!=last_frameID+1){
                    printf("Frame ID mismatch: Last %u, now %u at line %d\n",last_frameID,fID,nline);
                }
                if(fasyn!=0) printf("FrameID async flag in frame %u at line %d",fID,nline);

                last_frameID=fID;
            }else
            if (boost::starts_with(line, "Frame Trailer")){
                if(!in_frame || in_header) {printf("DRC error: Unexpected Trailer at line %d\n",nline); return;};
                in_frame=false;
            }else
            if (boost::starts_with(line, "Hit data")){
                if(!in_frame || in_header) {printf("DRC error: Unexpected Hit Data at line %d\n",nline); return;};
                unsigned int raw, asic,type,ch,bhit,cc,fc,eflag;
                if(sscanf(line.c_str(),"Hit data	 RAW %x	ASIC %u	TYPE %x	  CH %u	 EBH %x	 ECC %x	 EFC %x	EFLG %x",&raw,&asic,&type,&ch,&bhit,&cc,&fc,&eflag)!=8){
                    printf("Skipping line (%d) %s\n",nline,line.c_str());
                    nSkipped_Readout++;
                    continue;
                };

                //last hit was type empty (i.e. E or first), new is E -> ERROR
                //last hit is not empty   (i.e. T),          new is E -> append E-data and store hit
                if(type==1){
                    if(thehit.IsEmpty){
                        printf("DRC error: Unexpected Type-E hit at line %d: Last empty=%c, Last ewritten=%c\n",nline,thehit.IsEmpty?'y':'n',thehit.EtypeWritten?'y':'n');
                        return;
                    }
                    if(thehit.asic!=asic || thehit.channel!=ch){
                        printf("DRC error: Mismatch in asic/channel for long event\n");
                        return;
                    }
                    thehit.ebh=bhit;
                    thehit.ecc=cc;
                    thehit.efine=fc;
                    if(thehit.eflag!=eflag){
                        printf("DRC error: Mismatch in eflag for long event\n");
                        return;
                    }
                    thehit.EtypeWritten=true;
                    hits_readout.push_back(thehit);
                    //printf("New readout hit (E)\n");
                    thehit.IsEmpty=true;
                }
                //last hit was type (dontcare), new is T -> fill info, store last hit if not empty
                else if(type==0){
                    if(!thehit.IsEmpty){
                        //printf("New readout hit (T)\n");
                        hits_readout.push_back(thehit);
                    }
                    thehit.asic=asic;
                    thehit.channel=ch;
                    thehit.tbh=bhit;
                    thehit.tcc=cc;
                    thehit.tfine=fc;
                    thehit.eflag=eflag;
                    thehit.IsEmpty=false;
                }
                else{
                    printf("Wrong type %u at line %d\n",type,nline);
                    nSkipped_Readout++;
                }


            }else{
                printf("Unrecognized line start: %s %d\n",line.c_str(),nline);
                nSkipped_Readout++;
            }
            nline++;
        }
    }
    int nParsed_Readout=hits_readout.size();

/*
    cout<<"Hits from TDC:"<<endl;
    for(auto ahit : hits_TDC){
        PrintHit(ahit);
    }
    cout<<"Hits from Readout:"<<endl;
    for(auto ahit : hits_TDC){
        PrintHit(ahit);
    }
*/

    cout<<"Starting analysis"<<endl;
    for(auto hit_ro : hits_readout){
        PrintHit(hit_ro);
        //printf("Searching...\n");
        hit hit_TDC=PopFirstInTDC(hits_TDC,hit_ro.asic,hit_ro.channel);
        if(hit_TDC.IsEmpty){
            printf("No candidate found, exiting\n");
            return;
        }
        PrintHit(hit_TDC,"Found: ");
        if(hit_ro.compare(hit_TDC))
            printf("                -->  Match!\n");
        else{
            printf("                -->  No match :(\n");
            PrintHit(hit_ro,"Readout: ");
            PrintHit(hit_TDC,"TDC:     ");
            return;
        }
    }
    cout<<"Summary: "<<endl;
    cout<<"Parsed "<<nParsed_TDC<<" hits from TDC File"<<endl;
    cout<<"Skipped"<<nSkipped_TDC<<" unreadable hits from TDC File"<<endl;
    cout<<"Skipped"<<nExcluded_TDC<<" duplicate hits from TDC File"<<endl;

    cout<<"Parsed "<<nParsed_Readout<<" hits from Readout File"<<endl;
    cout<<"Skipped"<<nSkipped_Readout<<" unreadable hits from Readout File"<<endl;
    cout<<"Remaining unmatched hits from TDC at the end of the file:"<<endl;
    for(auto ahit : hits_TDC){
        PrintHit(ahit);
    }

}
