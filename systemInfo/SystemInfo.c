#include<stdio.h>
#include<stdlib.h>
#include<errno.h>
#include<sys/utsname.h>
int main(){
    struct utsname buff;
    if(uname(&buff)!=0){
       perror("Uname doesnt return 0, So there is an error !");
       exit(EXIT_FAILURE);
    }
    printf("System name = %s\n",buff.sysname);
    printf("System name = %s\n",buff.nodename);
    printf("Release = %s\n",buff.release);
    printf("Version = %s\n",buff.machine);


}