#include <stdlib.h>
#include <string.h>
#include <stdio.h>

void print_stats(char *start, char *cr_start, char *cr_end)
{
	printf("Stats : start : %p,  cr_start %p,  cr_end %p\n",
			start,
			cr_start - start,
			cr_end - start
	);
}

int isDelim(char c){
   switch(c){
      case '\0':
      case '\t':
      case ' ' :
         return 1;
         break; /* As a matter of style, put the 'break' anyway even if there is a return above it.*/
      default:
         return 0;
   }
}

int printLine(const char * start, const char * end){
   const char * p = start;
   while ( p <= end ) putchar(*p++);
   putchar('\n');
   return 0;
}

int main ( int argc , char ** argv ) {

   if( argc <= 2 ) exit(1);

   char * input_string = argv[1];
   int wrapLength = atoi(argv[2]);

   char * start = input_string;
   char * lastDelim = start;
   char * current = start;
   int chars = 1;

   char *crossover_word_start = start;
   char *crossover_word_end = start;

   char c = *current;

   puts(input_string);

   /* Go to 80 chars */
   while(c != 0){
      lastDelim = start;
      while((c = *current++) != 0 && chars++ <= wrapLength ){
         if( isDelim(c) ){
            lastDelim = current - 1;
			crossover_word_start = current;
		 }
      }
	  while((c = *current++) != 0 && !isDelim(c)){}
	  crossover_word_end = current - 1;

	  print_stats(start, crossover_word_start, crossover_word_end);
	  if( start == crossover_word_start ){
		  printLine(start, crossover_word_end);
		  start = crossover_word_end + 1;
	  } else {
		  printLine(start,lastDelim);
		  start = lastDelim + 1;
	  }
      chars = 1;
   }



   return 0;
}
