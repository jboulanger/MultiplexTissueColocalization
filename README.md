# Multiplex Tissue Colocalization

## Description
This repository contains an ImageJ macro for the analysis of the distance between cells markers in tissues.

Nuclei in the reference channels are segmented using the stardist pre-trained neural network. A watershed is used to expand the nuclei to approximate the cells boundaries. In each regions the intensity in each channel is recorded. Positive cells for each marker are then determined by analyzing the overall distribution of cell intensity. Cells are then counted in classes as defined by the user.

## Installation
To use this code, you need to install Fiji and activate the following update sites: CSBDeep, Startdist, IJPB-plugins.

## Usage
Open the file Multiplex_Tissue_Colocalization.ijm in Fiji and press run. The following 