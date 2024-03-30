#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include "cpp_utils.h"
#include "env.h"
#include "Network.h"
#include "util.h"

int _R0;

/*
                           0b001         0x33
    +--------------+-----+-------+----+---------+
    | simm12[11:0] | rs1 | func3 | rd | opcode6 |
    +--------------+-----+-------+----+---------+
    31             20    15      12   7         0
*/
#ifndef MADSIV
#define MADSIV(R1, Imm) asm volatile(".insn s 0x23, 0x4, %1, %2(a0)\n":"=r"(_R0):"r"(R1),"i"(Imm):); 
#endif

#ifndef MADSWV
#define MADSWV(R1, Imm) asm volatile(".insn s 0x23, 0x5, %1, %2(a0)\n":"=r"(_R0):"r"(R1),"i"(Imm):); 
#endif

#ifndef MADEV
#define MADEV(Rd) asm volatile(".insn r 0x33, 0x1, 0x03, %0, a0, a0\n":"=r"(Rd):); 
#endif



void readStimulus(
                  UDATA_T* inputBuffer,
                  Target_T* expectedOutputBuffer)
{
    envRead(ENV_SIZE_Y*ENV_SIZE_X*ENV_NB_OUTPUTS,
            ENV_SIZE_Y, ENV_SIZE_X,
            (DATA_T*) inputBuffer, //TODO
            OUTPUTS_SIZE[0], expectedOutputBuffer);
}

int processInput(        UDATA_T* inputBuffer,
                            Target_T* expectedOutputBuffer,
                            Target_T* predictedOutputBuffer,
			    UDATA_T* output_value)
{
    size_t nbPredictions = 0;
    size_t nbValidPredictions = 0;

    propagate(inputBuffer, predictedOutputBuffer, output_value);

    // assert(expectedOutputBuffer.size() == predictedOutputBuffer.size());
    for(size_t i = 0; i < OUTPUTS_SIZE[0]; i++) {
        if (expectedOutputBuffer[i] >= 0) {
            ++nbPredictions;

            if(predictedOutputBuffer[i] == expectedOutputBuffer[i]) {
                ++nbValidPredictions;
            }
        }
    }

    return (nbPredictions > 0)
        ? nbValidPredictions : 0;
}


int main(int argc, char* argv[]) {
    // printf("i\n");
    // int input = 0x00000A01;
    // MADSIV(input, 1);
    // input = 0x00000004;
    // MADSIV(input, 1);
    // printf("w\n");
    // int weight = 0x00000202;
    // MADSWV(weight, 1);
    // weight = 0x00000002;
    // MADSWV(weight, 1);
    // printf("r\n");
    // int result = 0;
    // MADEV(result);
    // printf("Result: %d\n", result);

    // input = 0x00000001;
    // MADSIV(input, 4);
    // weight = 0x00000002;
    // MADSWV(weight, 4);
    // result = 0;
    // MADEV(result);
    // printf("Result 2: %d\n", result);
    // return 1;
    // const N2D2::Network network{};
    size_t instret, cycles;

#if ENV_DATA_UNSIGNED
    UDATA_T inputBuffer[ENV_SIZE_Y*ENV_SIZE_X*ENV_NB_OUTPUTS];
#else
    std::vector<DATA_T> inputBuffer(network.inputSize());
#endif

    Target_T expectedOutputBuffer[OUTPUTS_SIZE[0]];
    Target_T predictedOutputBuffer[OUTPUTS_SIZE[0]];
    UDATA_T output_value;

    readStimulus(inputBuffer, expectedOutputBuffer);
    instret = -read_csr(minstret);
    cycles = -read_csr(mcycle);
    const int success = processInput(inputBuffer, 
                                                        expectedOutputBuffer, 
                                                        predictedOutputBuffer,
							&output_value);
    instret += read_csr(minstret);
    cycles += read_csr(mcycle);
    
    printf("Expected  = %d\n", expectedOutputBuffer[0]);
    printf("Predicted = %d\n", predictedOutputBuffer[0]);
    printf("Result : %d/1\n", success);
    printf("credence: %d\n", output_value);
    printf("image %s: %d instructions\n", stringify(MNIST_INPUT_IMAGE), (int)(instret));
    printf("image %s: %d cycles\n", stringify(MNIST_INPUT_IMAGE), (int)(cycles));

#ifdef OUTPUTFILE
    FILE *f = fopen("success_rate.txt", "w");
    if (f == NULL) {
        N2D2_THROW_OR_ABORT(std::runtime_error,
            "Could not create file:  success_rate.txt");
    }
    fprintf(f, "%f", successRate);
    fclose(f);
#endif
}
