#include<stdio.h>
#include<time.h>

void func_name(){
    printf("Function starts \n");
    printf("Press any key to stop function \n");
    for(;;){
        if(getchar())
           break;
    }
    printf("Function ends \n");
}
int main(){
    clock_t t; //
    t=clock();
    func_name();
    t=clock()-t;
    double time_taken_by_func = ((double)t)/CLOCKS_PER_SEC;
    printf("Time taken by function : %f",time_taken_by_func);

}