# Hardware Accelerator for Three Sequence Alignment
Special Problem, Fall 2017 ~ Spring 2019,  National Taiwan University  
Laboratory for Data Processing System  
Advisor: Yi-Chang Lu

## Summary
1. My research interests are architecture design and hardware accleration of miscellaneous algorithms in bioimatics.   
2. This repo contains my contributions to the RTL design of Three Sequence Alignment acclerator.


## Publication
**Three-Dimensional Dynamic Programming Accelerator for Multiple Sequence Alignment**  
2018 IEEE Nordic Circuits and Systems Conference (NORCAS): NORCHIP and International Symposium of System-on-Chip (SoC)  
Full Paper Link: https://ieeexplore.ieee.org/document/8573523  

### Abstract
Three sequence alignment can be used to improve the accuracy of multiple sequence alignment in genomics. In this paper, we design a hardware accelerator for three-dimensional dynamic programming algorithm of three sequence alignment. By utilizing parallel processing elements, our design can find the optimal alignment scores in a shorter time than that required by software. In addition, we propose a memory-efficient slicing method for three-dimensional dynamic programming in order to process sequences of longer lengths. The hardware accelerator is implemented on both FPGA and ASIC. The ASIC implementation using TSMC 40nm technology can achieve at least 160× speedup over the software implementation.

### Motivation
<img src=https://github.com/timmy139710/HW-Accelerator-Three-Sequence-Alignment/blob/master/pic/Motivation.png alt="moti" width=500 height=400> 


### Algorithm
<img src=https://github.com/timmy139710/HW-Accelerator-Three-Sequence-Alignment/blob/master/pic/Algorithm.png alt="algo" width=325 height=700> 

### Hardware Architecture
<img src=https://github.com/timmy139710/HW-Accelerator-Three-Sequence-Alignment/blob/master/pic/Architecture.png alt="arch" width=450 height=430> 
<img src=https://github.com/timmy139710/HW-Accelerator-Three-Sequence-Alignment/blob/master/pic/Memory.png alt="mem" width=450 height=350> 

### Parallel-Processing Element (PE)
<p align="left">
<img src=https://github.com/timmy139710/HW-Accelerator-Three-Sequence-Alignment/blob/master/pic/3DDP.png alt="p1" width=400 height=400> 
<img src=https://github.com/timmy139710/HW-Accelerator-Three-Sequence-Alignment/blob/master/pic/PE.png alt="p2" width=350 height=400> 
</p>

### Result
<img src=https://github.com/timmy139710/HW-Accelerator-Three-Sequence-Alignment/blob/master/pic/Result.png alt="res" width=450 height=200> 

### Chip Layout
<p align="left">
<img src=https://github.com/timmy139710/HW-Accelerator-Three-Sequence-Alignment/blob/master/pic/Layout.png alt="lay" width=400 height=400> 
<img src=https://github.com/timmy139710/HW-Accelerator-Three-Sequence-Alignment/blob/master/pic/Spec.png alt="spec" width=230 height=175> 
</p>
