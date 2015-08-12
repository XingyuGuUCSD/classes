#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <pthread.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <errno.h>
#include <time.h>
#include <netdb.h>
#include <sys/time.h>
#include <arpa/inet.h>
#include <math.h>


typedef unsigned long long ticks;

ticks getticks(void)
{	
     unsigned a, d;
     asm volatile("rdtsc" : "=a" (a), "=d" (d));

     return (((ticks)a) | (((ticks)d) << 32));
}

int
main(int argc, char *argv[]){

	int listen_port;
	int msg_size;
	int tries;
	struct sockaddr_in addr_serv;
	struct sockaddr_in addr_client;
	int sckTemp;
	int sckListen;
	socklen_t sinSize;
	int i, j, k;
	int tmp;
	char input[1000];
	char input2[1000];
  	struct sockaddr_in switchAddr;
	int skt;

	if (argc!=4){  	
		printf("Usage: ./CON_loopback <port> <msg_size> <samples>\n");
		exit(1);
	}
  
	listen_port = atoi(argv[1]); 
	if(listen_port<1024 || listen_port>32768){
		printf("\nInvalid port\n");
		exit(1);
	}
  
	msg_size = atoi(argv[2]);
	if(msg_size < 1){
		printf("\nmsg_size\n");
		exit(1);
	}	
	
	tries = atoi(argv[3]);
	if(tries < 1){
		printf("\ntries\n");
		exit(1);
	}	


	char msg[msg_size];
	ticks tear_results[tries];
	ticks setup_results[tries];  
	ticks start, end;  
	  
	for(i=0; i<msg_size; i++){
		msg[i] = 'a';
	}
	
		sinSize = sizeof(struct sockaddr_in);  
		sckListen = socket(AF_INET,SOCK_STREAM,0);
		addr_serv.sin_family = AF_INET;
		
		addr_serv.sin_port = htons(listen_port);
		addr_serv.sin_addr.s_addr = htonl(INADDR_ANY);
  
		if(bind(sckListen,(struct sockaddr *)&addr_serv,sizeof(struct sockaddr))<0){
			perror("bind");
			exit(1);
		}

		if(listen(sckListen,50)<0){
			perror("listen");
			exit(1);
		}

	for(i=0; i<tries; i++){ 	
		switchAddr.sin_family = AF_INET;
		switchAddr.sin_port = htons(listen_port); 
		switchAddr.sin_addr.s_addr = inet_addr("127.0.0.1");
  
		skt = socket(AF_INET,SOCK_STREAM,0);
		fcntl(skt, F_SETFL, O_NONBLOCK);

			 
		start = getticks();

		connect(skt, (struct sockaddr *)&switchAddr, sizeof(switchAddr))

		sckTemp = accept(sckListen,(struct sockaddr *)&addr_client, &sinSize);	  

		end = getticks();
		setup_results[i] = end-start;

		if(write(skt, msg, strlen(msg)) < 0){
			perror("write socket");
		} 

		bzero(input, sizeof (input)); 
		tmp = read(sckTemp, input, sizeof (input));

		if(write(sckTemp, input, strlen(input)) < 0){
			perror("write socket");
		} 

		bzero(input2, sizeof (input)); 
		tmp = read(skt, input2, sizeof (input2));
	
		start = getticks();
		
		close(skt); 
		close(sckTemp);

		end = getticks();
		tear_results[i] = end-start;

	}
	
	double setup_avg =0, tear_avg=0, setup_stdv=0, tear_stdv=0, setup_t, tear_t;
	ticks setup_sum, tear_sum =0;
	
	for(i=0; i<tries; i++){
		setup_sum+= setup_results[i];
		tear_sum+= tear_results[i];
	}	
	setup_avg = ((double)setup_sum)/tries;
	tear_avg = ((double)tear_sum)/tries;
	
	setup_t = setup_avg/3.5;
	tear_t = tear_avg/3.5;
	printf("Setup:\tAverage cycles: %lf\n", setup_avg);
	printf("Tear:\tAverage cycles: %lf\n", tear_avg);

	return 0;
}
