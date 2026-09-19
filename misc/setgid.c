#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>

int main(int argc, char **argv){

    if(argc > 1){
        if(setpgid(0,getpid())){
            perror("setpgid");
            return 1;
        }
    }
    sleep(100);
    return 0;
}

