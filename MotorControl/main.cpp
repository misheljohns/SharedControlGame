#include <simplecat/Master.h>
#include <simplecat/Beckhoff/Beckhoff.h>

#include <stdlib.h>
#include <stdio.h>
#include <time.h>
#include <sched.h>
#include <sys/mman.h>
#include <string.h>
#include "tcp_client.cpp"

#define MY_PRIORITY (49) /* we use 49 as the PRREMPT_RT use 50
    as the priority of kernel tasklets
    and interrupt handler by default */

#define MAX_SAFE_STACK (8*1024) /* The maximum stack size which is
    guaranteed safe to access without
    faulting */

#define NSEC_PER_SEC    (1000000000) /* The number of nsecs per sec. */

void stack_prefault(void) {

    unsigned char dummy[MAX_SAFE_STACK];

    memset(dummy, 0, MAX_SAFE_STACK);
    return;
}

int main(int argc, char* argv[])
{
    struct timespec t;
    struct sched_param param;
    int interval = 1000000; /* 1ms */

    /* Declare ourself as a real time task */
    param.sched_priority = MY_PRIORITY;
    if(sched_setscheduler(0, SCHED_FIFO, &param) == -1) {
        perror("sched_setscheduler failed");
        exit(-1);
    }

    /* Lock memory */
    if(mlockall(MCL_CURRENT|MCL_FUTURE) == -1) {
        perror("mlockall failed");
        exit(-2);
    }

    /* Pre-fault our stack */
    stack_prefault();

    // beckhoff stack
    simplecat::Master master;
    simplecat::Beckhoff_EK1100 bh_ek1100;
    simplecat::Beckhoff_EL4134 bh_el4134;
    simplecat::Beckhoff_EL5002 bh_el5002;
    simplecat::Beckhoff_EL9505 bh_el9505;
    simplecat::Beckhoff_EL1124 bh_el1124;
    simplecat::Beckhoff_EL3104 bh_el3104;

    bh_el4134.write_data_[0] = 32767;
    bh_el4134.write_data_[1] = -32768;
    bh_el4134.write_data_[2] = 0;
    bh_el4134.write_data_[3] = 0;

    master.addSlave(1000,0,&bh_ek1100);
    master.addSlave(1001,0,&bh_el4134);
    master.addSlave(1002,0,&bh_el5002);
    master.addSlave(1003,0,&bh_el9505);
    master.addSlave(1004,0,&bh_el1124);
    master.addSlave(1005,0,&bh_el3104);

    master.activate();

    /* start after one second */
    printf("Running loop at [%.1f] Hz\n",((double)NSEC_PER_SEC)/((double)interval));
    clock_gettime(CLOCK_MONOTONIC ,&t);
    t.tv_sec++;

    /**** TCP ******/

    tcp_client c;
    string host;
    int port = 10002;
    host = "127.0.0.1";

    //connect to host
    c.conn(host, port);

    while(1)
    {
        /* wait until next shot */
        clock_nanosleep(CLOCK_MONOTONIC, TIMER_ABSTIME, &t, NULL);

        /* do the stuff */
        master.update();

        /* input */
        /* transformation */
        static double current_monitor[4];
        for(int i=0; i<4; i++)
        {
            if(bh_el3104.read_data_[i] > 0)
                current_monitor[i] = bh_el3104.read_data_[i]*2.5*10/32767.0;
            else
                current_monitor[i] = bh_el3104.read_data_[i]*2.5*10/32768.0;
        }
        static unsigned char hall_phase;
        hall_phase = bh_el1124.read_data_;

        /* output */
        static double U = 0;
        static double V = 0;
        static double amp = -0.3; //in volts
        switch(hall_phase)
        {
            case 5:
                {
                    U = amp;
                    V = 0;
                }
                break;
            case 4:
                {
                    U = 0;
                    V = 0;
                }
                break;
            case 6:
                {
                    U = 0;
                    V = amp;
                }
                break;
            case 2:
                {
                    U = -amp;
                    V = 0;
                }
                break;
            case 3:
                {
                    U = 0;
                    V = 0;
                }
                break;
            case 1:
                {
                    U = 0;
                    V = -amp;
                }
                break;

        }
        if(U > 0)
            bh_el4134.write_data_[0] = (int)(U/10.0*32767.0);
        else
            bh_el4134.write_data_[0] = (int)(U/10.0*32768.0);

        if(V > 0)
            bh_el4134.write_data_[1] = (int)(V/10.0*32767.0);
        else
            bh_el4134.write_data_[1] = (int)(V/10.0*32768.0);

        /***********/



        //send some data
        //c.send_data(1.234);
        string data_sending = "1234.1234";
        c.send_data(data_sending);

        string data_received = c.receive(1024);

        /* print */
        static unsigned int printCntr = 0;
        //if(printCntr++ % 1000 == 0)
        //{
            printf("el3104 = %f,%f\n",current_monitor[0],current_monitor[1]);
            printf("el5002 = %d,%d\n",bh_el5002.read_data_[0],bh_el5002.read_data_[1]);
            printf("hall phase = %d\n",hall_phase);

            //receive and echo reply
            printf("data received : ");
            printf(data_received.c_str()); //data_received.c_str()
            printf("\n");

        //}

        /* calculate next shot */
        t.tv_nsec += interval;

        while (t.tv_nsec >= NSEC_PER_SEC)
        {
            t.tv_nsec -= NSEC_PER_SEC;
            t.tv_sec++;
        }
    }
}
