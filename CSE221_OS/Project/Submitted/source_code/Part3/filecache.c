#include <time.h>
#include <sys/time.h>
#include <sys/stat.h>

typedef unsigned long long ticks;

static __inline__ ticks getticks(void)
{
     unsigned a, d;
     asm("cpuid");
     asm volatile("rdtsc" : "=a" (a), "=d" (d));

     return (((ticks)a) | (((ticks)d) << 32));
}

int
main(int argc, char *argv[]){

    if (argc!=2){
	printf("\nERROR! Invalid number of parameters!\n");
	printf("Please use: ./filcache <filename>\n");
	exit(1);
    }

  int myFile;
  FILE* fout;
  ticks start, end;
  unsigned int* pages;
  int x, y, limit;
  char* buffer;
    long size;

    char *filename = argv[1];

    struct stat st;
    
    stat(filename, &st);
    size = st.st_size;
  
    buffer = (char*)malloc((2 * 4096) * sizeof(char));
  
  if ((unsigned long)buffer % 4096) {
    buffer += 4096 - (unsigned long)buffer % 4096;
  }

    limit = (size / 4096);
    myFile = open(filename, O_RDONLY);

    //Eval
    start = getticks();

    for(x = 0 ; x < 2 ; x++){
      lseek(myFile, 0, SEEK_SET);

      for(y = 0 ; y < limit ; y++){
        read(myFile, buffer, 4096);
      }
    }

    end = getticks();
    close(myFile);

    ticks total = end - start;
    double time = (total / ((double) limit));
    int mb = size / (1024 * 1024);
    double speed = (3.5e9 * limit * 2 * 4096) / total;
    speed /= (1024 * 1024);

    printf("%dM %.3lf %.3lf\n", mb, time, speed);
  return 0;
}
