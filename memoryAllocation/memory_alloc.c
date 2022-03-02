#include<stdio.h>
#include<stdlib.h>
int main(){
    int num=8,data,i;

    printf("We have %d elements to allocate memory to\n",num);
    int *ptr = (int*)malloc(num*sizeof(int));
    if(ptr==NULL){
        printf("Memory allocation failed !");
        exit(0);
    }
    else{
        printf("Memory allocation has been successful\n");
    }
    for(int i=0;i<num;++i){
        *(ptr+i)=i+1;
    }
    printf("\nInserted 8 elements in the block are as follows..\n");
    for(int i=0;i<num;++i){
        printf("%d, ",ptr[i]);
    }
}
