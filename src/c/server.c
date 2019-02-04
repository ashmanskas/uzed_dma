/*
 * server.c : SMTP-style TCP server for register-file "bus" I/O
 *
 * - begun 2018-11-01 by Weiwei Hu <wei4wei@gmail.com>
 * - see https://github.com/husinthewei/rocstar_smtp
 *
 */

#include <unistd.h> 
#include <stdio.h> 
#include <sys/socket.h> 
#include <stdlib.h> 
#include <netinet/in.h> 
#include <string.h> 
#include <ctype.h> 
#include "busio.h"

#define PORT 2525
#define MEMSIZE 65536
#define MAXMSGSIZE 1024

static int memory[MEMSIZE];

// Temporarily read from fake memory
// Returns 1 iff success
int bus_rd(unsigned int addr, unsigned int *data) 
{
    if ((addr & 0x10000)!=0) {
        // Use address bit 16 to flag 'artix7' / 'spartan6' read
        addr &= 0xffff;
        *data = a7rd(addr);
        printf("a7rd(%x) -> %x\n", addr, *data);
        return 1;
    }

    if (addr < 0 || addr >= MEMSIZE) {
        *data = 0;
        return 0;
    }

  *data = busrd(addr);
  printf("busrd(%x) -> %x\n", addr, *data);
  return 1;
}

// Temporarily write to fake memory
// Returns 1 iff success
int bus_wr(unsigned int addr, unsigned int data) 
{
    if ((addr & 0x10000)!=0) {
        // Use address bit 16 to flag 'artix7' / 'spartan6' read
        addr &= 0xffff;
        a7wr(addr, data);
        return 1;
    }

    if (addr < 0 || addr >= MEMSIZE)
        return 0;

    buswr(addr, data);
    return 1;
}

// Returns the number of tokens
// deliminated by space
int num_tokens(char *str) {
    char *token = strtok(str, " \t");
    int count = 0;

    while (token != NULL) 
    {
        token = strtok(NULL, " \t");
        count++;
    }

    return count;
}

// Performs n reads
void bus_rd_n (char *cmd, char *response, unsigned int n) 
{
    char *response_curr = response;
    unsigned int addr;
    unsigned int val;

    char *token = strtok(cmd, " \t");
    int count = 0;

    sprintf(response, "250 RN %04d", n);
    response_curr += strlen(response);

    while (token != NULL) 
    {
        // Break and error if not a number
        if (sscanf(token, "%x", &addr) != 1 && count > 1) 
        {
            // Setting count guarantees error message
            count = n-1;
            break;
        } 
        // Otherwise, add the data to response
        else if (count > 1)
        {
            bus_rd(addr, &val);
            response_curr += sprintf(response_curr, " %04x %04x", addr, val);
        }

        token = strtok(NULL, " \t");
        count++;
    }

    sprintf(response_curr, "\n");

    if (count != n + 2) 
    {
        sprintf(response, "500 %d\n", n);
    }
}


// Performs n writes
// On error, responds 500 <SP> {write command fo error} <CRLF>
void bus_wr_n (char *cmd, char *response, unsigned int n) 
{
    char *response_curr = response;
    unsigned int addr;
    unsigned int val;

    char *token = strtok(cmd, " \t");
    int err = 0;
    int fail_no = 0;
    int count = 0;

    sprintf(response, "250 WN %04d", n);
    response_curr += strlen(response);

    // Perform writes
    while (token != NULL && !err) 
    {
        if (sscanf(token, "%x", &val) != 1 && count > 1) 
        {
            err = 1;
        } 
        // Address
        else if (count > 1 && count % 2 == 0) 
        {
            addr = val;
        } 
        // Data
        else if (count > 1)
        {
            int success = bus_wr(addr, val);

            if (success) 
                response_curr +=
                  sprintf(response_curr, " %04x %04x", addr, val);
            else
                err = 1;
        }

        token = strtok(NULL, " \t");
        count++;
    }

    fail_no = (count - 1) / 2;

    if (err || count != (2 * n) + 2) 
        sprintf(response, "500 %d\n", fail_no);
}

// Parse the command and form a response
char *parse_command(char *cmd) {
    char *response = malloc(MAXMSGSIZE);
    unsigned int addr;
    unsigned int val;
    unsigned int n;

    for (char *p = cmd; *p; p++) *p = toupper(*p);
    if (sscanf(cmd, "R %x\n", &addr) == 1) 
    {
        bus_rd(addr, &val);
        sprintf(response, "250 R %04x %04x\n", addr, val);
    }
    else if (sscanf(cmd, "W %x %x", &addr, &val) == 2) 
    {
        bus_wr(addr, val);
        sprintf(response, "250 W %04x %04x\n", addr, val);
    } 
    else if (sscanf(cmd, "RN %d*", &n) == 1) 
    {   
        bus_rd_n(cmd, response, n);
    } 
    else if (sscanf(cmd, "WN %d*", &n) == 1) 
    {
        bus_wr_n(cmd, response, n);
    }
    else if (!strncmp(cmd, "Q", strlen("Q")))
    {
        sprintf(response, "QUIT\n");
    } 
    else if (!strncmp(cmd, "NOOP", strlen("NOOP")))
    {
        sprintf(response, "250 NOOP\n");
    }
    else {
        sprintf(response, "500\n");
    }

    return response;
}

int main(int argc, char const *argv[]) 
{ 
    int server_fd, sock;
    struct sockaddr_in address; 
    int opt = 1; 
    int addrlen = sizeof(address); 
    char buffer[MAXMSGSIZE + 1] = {0}; 
       
    memset(memory, MEMSIZE, 0);

    // Creating socket file descriptor 
    if ((server_fd = socket(AF_INET, SOCK_STREAM, 0)) == 0) 
    { 
        perror("socket failed"); 
        exit(EXIT_FAILURE); 
    } 
       
    // Forcefully attaching socket to the port 8080 
    if (setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, 
                                                  &opt, sizeof(opt))) 
    { 
        perror("setsockopt"); 
        exit(EXIT_FAILURE); 
    } 
    address.sin_family = AF_INET; 
    address.sin_addr.s_addr = INADDR_ANY; 
    address.sin_port = htons( PORT ); 
       
    // Forcefully attaching socket to the port 2525 
    if (bind(server_fd, (struct sockaddr *) &address,  
                                 sizeof(address))<0) 
    { 
        perror("bind failed"); 
        exit(EXIT_FAILURE); 
    } 
    if (listen(server_fd, 3) < 0) 
    { 
        perror("listen"); 
        exit(EXIT_FAILURE); 
    } 

    int outerdone = 0;
    while (!outerdone) {
      // This loop will probably be replaced by whatever code later
      // implements fork() for each new incoming connection.
      
      if ((sock = accept(server_fd, (struct sockaddr *)&address,  
                         (socklen_t*)&addrlen))<0) 
        { 
          perror("accept"); 
          exit(EXIT_FAILURE); 
        } 

    
      int done = 0;

      int num_read;
      char *response;

      // Continuously read and execute commands
      // received from client
      while (!done) 
        {
          num_read = read(sock, buffer, MAXMSGSIZE); 
          buffer[num_read] = '\0';
          printf("Recv: %s", buffer); 
        
          response = parse_command(buffer);

          if (!strcmp(response, "QUIT\n")) 
            break;

          send(sock, response, strlen(response), 0);
          printf("Sent: %s\n", response);

          free(response);
        }

      close(sock);
    }  // while (!outdrdone);

    return 0; 
}


// Local Variables:
// c-basic-offset: 4
// End:
