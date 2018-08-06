
void buswr(int addr, int data);
int busrd(int addr);
int a7rd(int addr);
void a7wr(int addr, int data);
void clkdiv(void);
void clkdiv_word(int ireg, int data);
void clkcln_word(int ireg, int data);
void shreg(int led, int pdwn9222, int pdwn9287,
	   int drsreset, int calena, int calclkena);
int iv_word(int chain, int a, int b);
int rofiforead(long long *databuf, int databuflen);
