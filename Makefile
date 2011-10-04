jtool: dbgprog 
    
cmd.tab.c: src/cmd.y
	bison -r all -d -p cmd src/cmd.y

jass.tab.c: src/jass.y
	bison -r all -d -p jass src/jass.y
    
cmd.yy.c: src/cmd.l
	flex -o cmd.yy.c -P cmd src/cmd.l

jass.yy.c: src/jass.l
	flex -o jass.yy.c -P jass src/jass.l
    
clean:
	-rm jass.tab.c jass.tab.h jass.yy.c *.o jass.output cmd.tab.c cmd.tab.h cmd.yy.c cmd.output

prog: jass.tab.c jass.yy.c cmd.tab.c cmd.yy.c src/misc.c
	gcc -c -O3 -Wall cmd.tab.c
	gcc -c -O3 -Wall cmd.yy.c
	gcc -c -O3 -Wall jass.tab.c
	gcc -c -O3 -Wall jass.yy.c
	gcc -c -O3 -Wall src/misc.c
	gcc -o jtool -Wall jass.tab.o jass.yy.o cmd.tab.o cmd.yy.o misc.o -lreadline -lhistory 

dbgprog: clean jass.tab.c jass.yy.c cmd.tab.c cmd.yy.c src/misc.c
	gcc -g -c -O0 -Wall jass.tab.c
	gcc -g -c -O0 -Wall jass.yy.c
	gcc -g -c -O0 -Wall cmd.tab.c
	gcc -g -c -O0 -Wall cmd.yy.c
	gcc -g -c -O0 -Wall src/misc.c
	gcc -g -O0 -Wall -o jtool jass.tab.o jass.yy.o cmd.tab.o cmd.yy.o misc.o -lreadline -lhistory 
