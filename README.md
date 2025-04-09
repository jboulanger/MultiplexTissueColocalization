# Multiplex Tissue Colocalization

## Description
This repository contains an ImageJ macro for the analysis of the distance between cells markers in tissues.

Nuclei in the reference channels are segmented using the stardist pre-trained neural network. A watershed is used to expand the nuclei to approximate the cells boundaries. In each regions the intensity in each channel is recorded. Positive cells for each marker are then determined by analyzing the overall distribution of cell intensity. Cells are then counted in classes as defined by the user.

## Installation
To use this code, you need to install [Fiji](https://imagej.net/software/fiji/downloads) and activate the following update sites: [CSBDeep](https://imagej.net/plugins/csbdeep), [Startdist](https://imagej.net/plugins/stardist), [IJPB-plugins](https://imagej.net/plugins/morpholibj).

The code was tested with Fiji 1.54f.

## Usage
Open the file Multiplex_Tissue_Colocalization.ijm in Fiji and press run or batch. The following window will appear:

![image](https://github.com/user-attachments/assets/2832e518-ee58-4904-8900-78f681f94e07)

Select the file(s) you want to process and set the next parameters
- Channel names: enter the name of the channels in order and matching the actual number of channels separated by commas, for example: DAPI,FITC,Cy3
- Channel with nuclei labeling: enter the name of the channel corresponding to the nuclear marker, for example: DAPI.
- Reference channel:Name of the channel used to compute distance to, for example FITC.
- Combined channels code: code for the regions based on the channels intensitym for example: Cy3+ is a region positive for the Cy3 channel, Cy3+:FITC+ is a region positive for Cy3 and FITC.
- Save: indicate whether results should be saved
- Action: Set the operating mode of the macro: either "Run" to process images or "Check" to load previously generated results.