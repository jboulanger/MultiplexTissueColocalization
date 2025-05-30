//@File(label="Input file") filename
//@String(label="Channel names",value="A,B,C,D", description="comma separated list of names") channel_names_str
//@String(label="Channel with nuclei labeling",value="DAPI", description="name of the reference channel") nuclei_str
//@String(label="Reference channel",value="B", description="name of the reference channel (comma separated)") references_str
//@String(label="Combined channels code",value="A+:B+,C+:D+", description="comma separated list of codes eg A+:B+,A+:B-") codes_str
//@Boolean(label="Save",value=true) do_save
//@String(label="Action", style="", choices={"Run","Check","Test"}) mode

/*
 * Tissue colocalization
 *
 * Compute the distance of cells positives in marker the reference channel to
 * cell positive to a combination of markers (code)
 *
 * Codes syntax: A+:B+,A+:B-
 *
 * Installation
 * CSBDeep, Startdist, IJPB-plugins
 *
 * Jerome for Leonor 2023
 */

 if (matches(mode, "Run")) {
 	runAnalysis(false);
 } else if (matches(mode, "Check")) {
 	checkPositive();
 } else if (matches(mode, "Test")) {
 	filename = "test.tif";
 	channel_names_str = "DAPI,FITC,Cy3,Cy5";
 	nuclei_str = "DAPI";
 	references_str = "FITC";
 	codes_str = "Cy3+,Cy5+,Cy3+:Cy5+";
 	do_save = false;
 	runAnalysis(true);
 }


function checkPositive() {
	/*
	 * Check positive cells
	 *
	 * Load the image and rois from previous analysis and draw positive reference cells as overlays
	 *
	 */

	run("Close All");

	references =  parseCSVString(references_str);
	setBatchMode("hide");

 	// Load the image
 	open(filename);

 	// Load the table
 	ofile = File.getDirectory(filename) + File.getNameWithoutExtension(filename) + "-results-table.csv";
 	open(ofile);
 	tbl1 = Table.title;
 	x = Table.getColumn("Positive ["+references[0]+"]");
 	ind = Table.getColumn("ROI Index");

 	// Load the ROIs
 	ofile = File.getDirectory(filename) + File.getNameWithoutExtension(filename) + "-rois.zip";
 	roiManager("open", ofile);

 	// Indentify positive cells
	k = 0;
	y = x;
	for (i = 0; i < x.length; i++) {
		if (x[i] > 0) {
			y[k] = ind[i];
			k++;
		}
	}
	y = Array.trim(y,k);

	// Create an overlay with the positive cells
	roiManager("select", y);
	roiManager("Combine");
	run("Add Selection...");
 	Overlay.show;
 	setBatchMode("exit and display");

 	print("done");
}

function runAnalysis(testmode) {
	/*
	 * Segment the image and compute the distances between markers
	 *
	 * Input
	 *  testmode (boolean): if we are running a test
	 *
	 * Output
	 * 	Tables and images
	 */

	do_pcc=false; // do pearson correlation coefficient?

	// Reset all table and windows
	start_time = getTime();
	print("\\Clear");
	run("Close All");
	tbl1 = "Measure per ROI.csv";
	tbl2 = "Summary.csv";
	closeWindow(tbl1);
	closeWindow("ROI Manager");

	// Open the file or generate a test image
	if (testmode) {
		createTestImage();
	} else {
		open(filename);
	}
	Overlay.remove();
	getPixelSize(pixel_unit, pixel_size, pixel_size);
	id = getImageID();

	setBatchMode("hide");

	// Parse the input parameters
	channel_names = parseCSVString(channel_names_str);
	channel_nuclei = indexOfArray(nuclei_str, channel_names) + 1;
	references = parseCSVString(references_str);
	codes = parseCSVString(codes_str);

	print("Input image: " + File.getNameWithoutExtension(filename));
	print("Channel names: " + array2csv(channel_names));
	print("Nuclei channel: " + nuclei_str + "(" + channel_nuclei + ")");
	print("Reference channels: " + array2csv(references));
	print("Combined channels: " + array2csv(codes));

	// Crop the active selection
	cropActiveSelection();

	// segment cells based on nuclei
	run("Select None");
	amax = getValue("Area");
	labels = segmentNuclei(id, channel_nuclei, 100, amax);

	rois = createROIfromLabels(labels);

	// segment positive cells
	//masks = mapPostiveROIs(id, rois);

	masks =  mapPositiveLabels(id, labels);

	// basic measurement for each segmented ROI
	measureInROI(tbl1, id, rois, channel_names, do_pcc, pixel_unit);

	// record positive channels
	positive = recordPositiveROIs(tbl1, masks, rois, channel_names);

	// decode rois based on segmented cells
	//decoded = decodeROIChannels(masks, rois, positive, channel_names, codes);
	decoded = decodeChannelsOld(masks, channel_names, codes);

	measureROIdistanceToLabels(tbl1, decoded, rois, codes, references, pixel_size, pixel_unit);

	summarizeTable(tbl1, tbl2, File.getNameWithoutExtension(filename), references, channel_names, codes, pixel_unit);

	if (do_save) {

		selectWindow(tbl1);
		ofile = File.getDirectory(filename) + File.getNameWithoutExtension(filename) + "-results-table.csv";
		print("Saving result table in " + ofile);
		Table.save(ofile);

		selectWindow(tbl2);
		ofile = File.getDirectory(filename) + File.getNameWithoutExtension(filename) + "-summary-table.csv";
		print("Saving summary table in " + ofile);
		Table.save(ofile);

		selectWindow("median");
		ofile = File.getDirectory(filename) + File.getNameWithoutExtension(filename) + "-cell-mean-intensity.tif";
		print("Saving intensities in " + ofile);
		saveAs("tiff", ofile);


		selectImage(masks);
		ofile = File.getDirectory(filename) + File.getNameWithoutExtension(filename) + "-masks.tif";
		print("Saving masks in " + ofile);
		saveAs("tiff", ofile);

		ofile = File.getDirectory(filename) + File.getNameWithoutExtension(filename) + "-rois.zip";
		roiManager("save", ofile);

	}

	//selectImage(masks); close();
	//selectImage(labels); close();
	//selectWindow("Codes");close();
	//selectWindow("median");close();

	selectImage(id);
	run("Select None");
	addROIsToOverlay(id, rois);
	run("Collect Garbage");
	run("Select None");
	setBatchMode("exit and display");
	print("Done in " + (getTime() - start_time) / 1000 + " seconds.");
	run("Collect Garbage");

}

/*
function analyzeDistances() {
	// load the table
 	ofile = File.getDirectory(filename) + File.getNameWithoutExtension(filename) + "-results-table.csv";
 	open(ofile);
 	tbl1 = Table.title;
 	P = Table.getColumn("Positive ["+references[0]+"]");
}
*/



function computeRingArea(rois, radius, thickness, domain) {
	/*
	 * Compute the area of the ring or given radius and thickness
	 * included in the domain.
	 *
	 * rois : array of roi indices
	 * radius : array of radiuses for each ring around each roi
	 * thickness : scalar thickness of the rings
	 * domain : index of the ROI serving as domain
	 *
	 * return the array of areas for each roi
	 */
	n = roiManager("count");
	C = newArray(rois.length);

	for (i = 0; i < rois.length; i++) {

		roiManager("select", rois[i]);

		// create a band ROI and add it to the ROI manager
		run("Enlarge...", "enlarge=" + radius[i]);
		roiManager("add"); // n
		a = roiManager("count")-1;

		run("Enlarge...", "enlarge="+thickness);
		roiManager("add"); // n + 1
		b = roiManager("count")-1;

		roiManager("select", newArray(n,n+1));
		roiManager("XOR");
		roiManager("add"); // n + 2
		c = roiManager("count")-1;

		// compute the intersection with the reference ROI 0
		roiManager("select", newArray(domain, n+2));
		roiManager("AND");
		Roi.setFillColor("green");
		run("Add Selection...");

		C[i] = getValue("Area");

		// remove the teporary ROIs
		roiManager("Deselect");
		for (k = n + 2; k >= n; k--) {
			roiManager("select", k);
			roiManager("delete");
		}
	}
	return C;
}


function array2csv(array) {
	/*
	 * Convert an array to comma separated string
	 */
	str="";
	for (i = 0; i < array.length; i++) {
		str += array[i];
		if (i < array.length-1) {
			str += ",";
		}
	}
	return str;
}

function indexOfArray(value, array) {
	/*
	 * Find the index of a value in an array
	 *
	 * Input:
	 * 	key: the value to search
	 * 	array: the array
	 * Output:
	 * 	First index (int) of the value in the array
	 */
	for (i = 0; i < array.length; i++) {
		if (array[i] == value) {
			return i;
		}
	}
	return -1;
}

function segmentNuclei(id, channel, min_area, max_area) {
 	/*
 	 * Segment nuclei using stardist, remove background and grow regions.
 	 * Segmented regions are added to the ROI manager
 	 *
 	 * Input
 	 *  id: in of the window
 	 *  channel (int): index the nuclear channel
 	 *  min_area: minimum area of the cells
 	 *  max_area: maximum area of the cells
 	 *
 	 * Output
 	 *  index of the label image
 	 */
 	print("Segmentation [ mem:" + round(IJ.currentMemory()/1e6)+"MB]");
 	name = getTitle();
 	selectImage(id);
 	run("Select None");

 	print("Creating  a mask [ mem:" + round(IJ.currentMemory()/1e6)+"MB]");
 	mask = createBackgroundMask(id, 10);

 	print("Running StarDist [ mem:" + round(IJ.currentMemory()/1e6)+"MB]");
 	run("Select None");
 	selectImage(id);
 	run("Duplicate...", "title=dapi duplicate channels="+channel);
	run("32-bit");
 	nuc = getImageID();
	run("Square Root");
	run("Minimum...", "radius=5");
	run("Maximum...", "radius=5");
	run("Enhance Contrast", "saturated=0.35");
	run("Subtract Background...", "rolling=50 stack");
	run("Command From Macro", "command=[de.csbdresden.stardist.StarDist2D], args=['input':'dapi','modelChoice':'Versatile (fluorescent nuclei)', 'normalizeInput':'true', 'percentileBottom':'5.0', 'percentileTop':'95.0', 'probThresh':'0.2', 'nmsThresh':'0.1', 'outputType':'Label Image', 'nTiles':'25', 'excludeBoundary':'0', 'roiPosition':'Automatic', 'verbose':'false', 'showCsbdeepProgress':'false', 'showProbAndDist':'false'], process=[false]");
 	selectImage("Label Image"); label = getImageID();
	run("Remap Labels");

 	print("Running Watershed [ mem:" + round(IJ.currentMemory()/1e6)+"MB]");
 	selectImage(label);
	run("Label Size Filtering", "operation=Greater_Than size=100");
	rename("Input");
	input = getImageID();

 	run("Marker-controlled Watershed", "input=[Input] marker=[Label Image] mask=[Mask] compactness=0 calculate use");
 	selectImage("Input-watershed"); watershed = getImageID();

 	run("Label Size Filtering", "operation=Greater_Than size="+min_area);
 	minid = getImageID();

	run("Label Size Filtering", "operation=Lower_Than size="+max_area);
	maxid = getImageID();

	run("Label Morphological Filters", "operation=Dilation radius=1");
	run("Remap Labels");
	rename("labels");
	dilated = getImageID();

 	closeImageList(newArray(nuc,mask,label,input,watershed,minid,maxid));

 	selectImage(dilated);
 	return dilated;
}

function createBackgroundMask(id, percentile) {
	/*
	 * Create a background mask
	 *
	 */
	selectImage(id);
	run("Duplicate...", "title=tmp duplicate");
	equalizeChannels(getImageID());
	run("8-bit");
	id1 = getImageID();
	run("Z Project...", "projection=[Average Intensity]");
	run("Median...", "radius=5");
	run("32-bit");
	t = calculatePercentile(percentile);
	setThreshold(t, getValue("Max"), "raw");
	run("Convert to Mask");
	id2 = getImageID();
	rename("Mask");
	run("Grays");
	roiManager("select", 0);
	if (!isSelectionAllImage()) {
		run("Make Inverse");
		setColor(0);
		fill();
	}
	selectImage(id1);close();
	return id2;
}

function isSelectionAllImage() {
	/* Return true if the selection is the all image or there is no selection*/
	getPixelSize(unit, pixelWidth, pixelHeight);
	getDimensions(width, height, channels, slices, frames);
	if (getValue("Area") == (width * height * pixelWidth * pixelHeight)) {
		return true;
	} else {
		return false;
	}
}

function calculatePercentile(percentage) {
	/* Compute a threshold based on a percentile of the image intensity */
	if (bitDepth() == 8) {
		nbins= 255;
		getHistogram(values, counts, nbins);
	} else {
		minbins = getValue("Min");
		maxbins = getValue("Max");
		nbins = maxOf(100, maxbins - minbins);
		getHistogram(values, counts, nbins, minbins, maxbins);
	}
	N = 0;
	for (i = 0;	i < counts.length; i++) {
		N += counts[i];
	}
	n = 0;
	for (i = 0; i < counts.length && n < percentage / 100 * N; i++) {
		n += counts[i];
	}
	return values[minOf(i, nbins-1)];
}

function calculateThreshold() {
	/* Compute a threshold based on a percentile of the image intensity */
	return getValue("Median") + getValue("StdDev");
}

function createROIfromLabels(id) {
	/*
	 * Create ROI from labels and add them to the ROI manager
	 */
	print("Creating ROIs [ mem:" + round(IJ.currentMemory()/1e6)+"MB]");
	selectImage(id);
	nlabels = getValue("Max");
 	print("  number of labels " + nlabels);
 	n0 = roiManager("count");
 	n = 0;
 	rois = newArray(nlabels);
 	for (i = 0; i < nlabels; i++) {
 		run("Select None");
 		if (i % 10 == 0) {
 			showProgress(i, nlabels);
 			showStatus("!creating in rois " + i + "/" + nlabels);
 		}
 		setThreshold(i+0.75, i+1.25);
 		run("Create Selection");
 		if (Roi.size > 0) {
 			roiManager("add");
 			roiManager("remove slice info");
 			roiManager("select", roiManager("count")-1);
 			roiManager("update");
 			rois[i] = n0 + i;
 			n++;
 		}
 		resetThreshold();
 	}
 	rois = Array.trim(rois, n-1);
 	print("  number of Rois " + rois.length);
 	return rois;
}

function measureInROI(tbl, id, rois, channel_names, do_pcc, pixel_unit) {
	/*
	 * Measurement for each ROI over all chanels.
	 * - Mean
	 * - Area
	 * - Colocalization
	 */
	 if (do_pcc) {
	 	print("Measure in "+rois.length+" ROIs [area,centroid,mean,pcc]");
	 } else {
	 	print("Measure in "+rois.length+" ROIs [area,centroid,mean]");
	 }
	 Table.create(tbl1);
	 selectImage(id);
	 Stack.getDimensions(width, height, channels, slices, frames);


 	selectImage(id);
 	selectWindow(tbl1);
 	for (i = 0; i < rois.length; i++) {

	 	if (i % 10 == 0) {
	 		showProgress(i+1, rois.length);
	 		showStatus("measure in rois " + i + "/" + rois.length);
	 	}

	 	roiManager("select", rois[i]);
	 	Table.set("ROI Index", i, rois[i]);
	 	Table.set("Name", i, Roi.getName);

	 	// Area
	 	Table.set("Area in "+pixel_unit+"^2", i, getValue("Area"));

	 	// location
	 	Table.set("X", i, getValue("X"));
	 	Table.set("Y", i, getValue("Y"));
 	}

	 // Mean in each channel
	 for (c1 = 1; c1 <= channels; c1++) {
	 	Stack.setChannel(c1);
	 	for (i = 0; i < rois.length; i++) {
	 		roiManager("select", rois[i]);
	 		Table.set("Mean ["+channel_names[c1-1]+"]", i, getValue("Mean"));
	 	}
 	}

	 Table.update;
	 run("Collect Garbage");
}

function getIntensities() {
	// Get the intensities inside the current ROI as an array
	Roi.getContainedPoints(xpoints, ypoints);
	values = newArray(xpoints.length);
	for (i = 0; i < xpoints.length; i++) {
		values[i] = getPixel(xpoints[i], ypoints[i]);
	}
	return values;
}

function spearman(x1,x2) {
	// https://en.wikipedia.org/wiki/Spearman%27s_rank_correlation_coefficient
	// The ranking function is not consistent with other statistical software
	r1 = Array.rankPositions(x1);
	r2 = Array.rankPositions(x2);
	pcc = pearson(r1,r2);
	return -pcc[0];
}

function pearson(x1, x2) {
	// Peason correlation coefficient
	// return an array  0:pcc,1:mu1,2:sigma1,3:mu2,4:sigma2
	if (x2.length != x1.length ) {
		print("non matching array length in prearson x1:"+x1.length+", x2:"+x2.length);
	}
	Array.getStatistics(x1, min1, max1, mu1, sigma1);
	Array.getStatistics(x2, min1, max1, mu2, sigma2);
	n = x1.length;
	sxy = 0;
	sxx = 0;
	syy = 0;
	for (i = 0; i < x1.length; i++) {
		sxy += (x1[i]-mu1)*(x2[i]-mu2);
		sxx += (x1[i]-mu1)*(x1[i]-mu1);
		syy += (x2[i]-mu2)*(x2[i]-mu2);
	}
	pcc = sxy / (sqrt(sxx)*sqrt(syy));
	return newArray(pcc,mu1,sigma1,mu2,sigma2);
}

function computeRobustThresholdOnArray(values, alpha) {
	/*
	 * Compute a threshold using median and median absolute deviation
	 *
	 * Input
	 * 	values (array): values from which to compute the threshold
	 * 	alpha (float): sensitivity
	 *
	 * Output
	 * 	float:value of the threshold
	 */
	tmp = Array.copy(values);
	Array.sort(tmp);
	m = tmp[round(tmp.length/2)];
	for (i = 0 ; i < tmp.length; i++) {
		tmp[i] = abs(tmp[i] - m);
	}
	Array.sort(tmp);
	return m + alpha * tmp[round(tmp.length/2)];
}


function measureROIdistanceToLabels(tbl, id, rois, channel_names, references, pixel_size, pixel_unit) {
	/*
	 * Record distance of each ROIs to the labels in id
	 *
	 * Input
	 *  tbl (str): name of the table
	 *  id (int): id of the window
	 *  rois (array): list of the ROIs indices
	 *  channel_names (array): list of the channel names
	 *  references (array): list of the reference channels
	 *  pixel_size (float): pixel size
	 *  pixel_unit (str): unit of the pixel size
	 *
	 *  Output
	 *   Populate the table tbl with distances to each channel
	 */
	print("Record distance to labels");
	selectImage(id);
	print("Distance to " + getTitle());
	run("Options...", "iterations=1 count=1 edm=32-bit do=Nothing");
	run("Distance Map", "stack");
	Stack.getDimensions(width, height, nchannels, nslices, nframes);
	for (i = 0; i < rois.length; i++) {
		roiManager("select", rois[i]);
		for (c = 1; c <= nchannels; c++) {
			Stack.setChannel(c);
			Table.set("Distance to [" + channel_names[c-1]+"] in " + pixel_unit, i, getValue("Min") * pixel_size);
		}
	}
	Table.update;
	close();
	run("Collect Garbage");
}

function measureROIRing(tbl, rois, codes, references, pixel_size, pixel_unit) {

}


function recordPositiveROIs(tbl, id, rois, channel_names) {
	/*
	 * Fill the table with a flag telling if the cell is positive in this channel
	 * Parameters:
	 * tbl: name of the table
	 * id: image id of the mask
	 * rois: list of ROIs
	 * channel_names : array of channel names
	 *
	 * Returns: values
	 */

	selectImage(id);
	print("recode positive ROI on mask image " + getTitle);
	values = newArray(rois.length * channel_names.length);
	for (i = 0; i < rois.length; i++) {
		Table.set("Index", i, rois[i]);
		roiManager("select", rois[i]);
		for (c = 0; c < channel_names.length; c++) {
			Stack.setChannel(c+1);
			v = getValue("Mean");
			if (v > 128) {
				Table.set("Positive [" + channel_names[c]  + "]", i, 1);
				values[i+c*rois.length] = 1;
			} else {
				Table.set("Positive [" + channel_names[c] + "]", i, 0);
				values[i+c*rois.length] = 0;
			}
		}
	}
	Table.update;
	return values;
}


function mapPositiveLabels(id, labels) {
	/*
	 * Create a map of positive ROI using a background sutraction and Otsu threshold
	 * 
	 * Input
	 *  id (int): image id 
	 *  labels (int): label image id
	 *
	 * Output
	 *  Returns the map of positive label for each channel
	 *  
	 */

	selectImage(labels);
	labelsname = getTitle();
	selectImage(id);
	Stack.getDimensions(width, height, nchannels, nslices, nframes);
	str =  "";
	for (c = 1; c <= nchannels; c++) {
		selectImage(id);
		run("Duplicate...", "title=tmp duplicate channels="+c);
		//run("Subtract Background...", "rolling=25 stack");
		run("Intensity Measurements 2D/3D", "input=tmp labels=["+labelsname+"] median mean");
		vals = Table.getColumn("Mean");
		Array.getStatistics(vals, min, max, mean, stdDev);
		selectImage(labels);
		call("inra.ijpb.plugins.LabelToValuePlugin.process", "Table=tmp-intensity-measurements", "Column=Median", "Min="+min, "Max="+max);
		rename("C"+c+"-median");
		str += "c"+c+"=C"+c+"-median ";
		selectWindow("tmp-intensity-measurements"); run("Close");
		selectWindow("tmp"); close();
	}
	//print(str);
	run("Merge Channels...", str +" create");
	rename("median");
	run("Duplicate...", "title=positive duplicate");
	run("Convert to Mask", "method=Otsu background=Dark calculate");
	run("Select None");
	return getImageID();
}


function mapPostiveROIs(id, rois) {
	/*
	 * Create a map of positive ROI using a background sutraction and Otsu threshold
	 * on the image of the median.
	 *
	 * Input
	 *  id  (int): image ID
	 *  rois (array): list of ROI id
	 *
	 * Output
	 * 	Returns the id of the map image
	 */
	print("Map positives");
	run("Select None");
	run("Duplicate...", "title=median duplicate");
	Stack.setDisplayMode("grayscale");
	run("Subtract Background...", "rolling=50 stack");
	id1 = getImageID();
	Stack.getDimensions(width, height, nchannels, nslices, nframes);
	for (c = 1; c <= nchannels; c++) {
		for (i = 0; i < rois.length; i++) {
			roiManager("select", rois[i]);
			run("Enlarge...", "enlarge=1");
			Stack.setChannel(c);
			v = getValue("Mean");
			setColor(v);
			fill();
		}
		roiManager("select", rois);
		roiManager("Combine");
		run("Make Inverse");
		run("Enlarge...", "enlarge=-1");
		setColor(0); fill();
		setMinAndMax(0, 255);
	}
	run("Duplicate...", "title=positive duplicate");
	run("Convert to Mask", "method=Otsu background=Dark calculate");
	run("Select None");
	return getImageID();
}


function decodeROIChannels(src, rois, values, channel_names, codes) {
	/*
	 * Decode channels based on a list of code ROI by ROI
	 *
	 * Parameters
	 *  src: id of the input image
	 *  channel_names : list of channel names in the order
	 *  codes: list of codes eg: ch1+:ch2+ (+ for positive, - for negative)
	 *
	 * Returns the id of the image with the codes
	 *
	 */

	selectImage(src);

	getDimensions(width, height, channels, slices, frames);
	newImage("Codes", "8-bit grayscale-mode", width, height, codes.length, 1, 1);
	dst = getImageID();

	for (k = 0; k < codes.length; k++) {
		segment = split(codes[k],":");
		for (ii = 0 ; ii < segment.length; ii++) { segment[ii] = String.trim(segment[ii]); }
		// analyze the code
		subset = newArray(segment.length);
		signs = newArray(segment.length);
		for (i = 0; i < segment.length; i++) {
			channel = substring(segment[i], 0, segment[i].length-1);
			channel_idx = getChannelIdx(channel_names, channel);
			sign = substring(segment[i], segment[i].length-1, segment[i].length);
			subset[i] = channel_idx;
			if (matches(sign,"\\+")) {
				signs[i] = 1;
			} else {
				signs[i] = 0;
			}
		}

		// apply the code to the ROIs
		selectImage(dst);
		for (i = 0; i < rois.length; i++) {
			test = true;
			for (i = 0; i < segment.length; i++) {
				c = subset[i];
				test = test && (values[i+c*rois.length]==signs[i]);
			}
			if (test) {
				setColor(255);
				roiManager("select", i);
				setSlice(k+1);
				fill();
			}
		}
	}
	return dst;
}

function parseCode(src) {
	/*
	 * Parse c+:d- channel codes and return an array with channel and sign
	 */
	segment = split(src,":");
	dst = newArray(2*segment.length);
	for (i = 0; i < segment.length; i++) {
		channel = substring(segment[i], 0, segment[i].length-1);
		sign = substring(segment[i], segment[i].length-1, segment[i].length);
		if (matches(sign,"\\+")) {
			dst[2*i] = channel;
			dst[2*i+1] = 1;
		} else {
			dst[2*i] = channel;
			dst[2*i+1] = 0;
		}
	}
	return dst;
}

function decodeChannelsOld(src, channel_names, codes) {
	/*
	 * Decode channels based on a list of code
	 *
	 * Input
	 *  src: id of the input image
	 *  channel_names : list of channel names in the order
	 *  codes: list of codes eg: ch1+:ch2+ (+ for positive, - for negative)
	 *
	 * Output
	 * Returns the id of the image with the codes
	 *
	 */

	selectImage(src);
	run("Select None");
	getDimensions(width, height, channels, slices, frames);
	newImage("Codes", "8-bit grayscale-mode", width, height, codes.length, 1, 1);
	dst = getImageID();

	for (k = 0; k < codes.length; k++) {
		print("\nCreating " + codes[k]);
		segment = split(codes[k],":");
		for (ii = 0 ; ii < segment.length; ii++) { segment[ii] = String.trim(segment[ii]); }
		subset = "";
		signs = newArray(segment.length);
		for (i = 0; i < segment.length; i++) {
			channel = substring(segment[i], 0, segment[i].length-1);
			channel_idx = getChannelIdx(channel_names, channel);
			sign = substring(segment[i], segment[i].length-1, segment[i].length);
			subset += "" + channel_idx + ",";
			if (matches(sign,"\\+")) {
				signs[i] = 1;
			} else {
				signs[i] = 0;
			}
		}
		subset = substring(subset, 0, subset.length-1);

		selectImage(src);
		run("Make Subset...", "channels="+subset);
		sid0 = getImageID();
		run("Duplicate...", "duplicate");
		sid = getImageID();
		for ( i = 0; i < signs.length; i++) {
			if (signs[i] == 0) {
				Stack.setChannel(i+1);
				run("Invert", "slice");
			}
		}
		if (nSlices > 1) {
			run("Z Project...", "projection=[Min Intensity]");
		} else {
			run("Duplicate...", "duplicate");
		}
		rename("MIP");
		mip = getImageID();
		run("Select None");
		run("Copy");

		selectImage(dst);
		setSlice(k+1);
		Overlay.drawString(""+(k+1)+" ~ "+codes[k], 10, 10);
		Overlay.setPosition(k+1);
		Overlay.add;
		Overlay.show();
		run("Select None");
		run("Paste");
		run("Select None");
		closeImageList(newArray(mip,sid0,sid));
	}
	return dst;
}

function getChannelIdx(list, name) {
	/*
	 * Return the index of the str in the list
	 *
	 * Inputs:
	 *  list : list of string
	 *  name :
	 */
	for (i = 0; i < list.length; i++) {
		if (matches(list[i], name)) {
			return i+1;
		}
	}
	return 0;
}

function summarizeTable(src, dst, filename, references, channel_names, codes, pixel_unit) {
	/*
	 * Summarize the result in a table with a line per image
	 *
	 * Inputs:
	 *	src (str): name of the source table
	 *	dst (str): name of the summary table
	 *	filename (str): the input filename
	 *	reference (array): list of reference channels
	 *	channel_names (array): list of the name of the channels
	 *	codes (array): list of the classes codes
	 *	pixel_unit (str): unit
	 */
	print("Preparing summary...");
	if (!isOpen(dst)) {Table.create(dst);}
	selectWindow(dst);
	row = Table.size;
	Table.set("File", row, filename);

	// total number of ROI
	selectWindow(src);
	n = Table.size;
	selectWindow(dst);
	Table.set("Number of ROIs", row, n);

	selectWindow(src);
	x = Table.getColumn("Area in " + pixel_unit + "^2");
	area = 0;
	for (i = 0; i < x.length; i++) {
		area += x[i];
	}
	selectWindow(dst);
	Table.set("Total area in " + pixel_unit + "^2", row, area);

	// count positive
	for (c = 0; c < channel_names.length; c++) {
		selectWindow(src);
		x = Table.getColumn("Positive [" + channel_names[c]  + "]");
		n = 0;
		for (i = 0; i < x.length; i++) {
			if (x[i]==1) {
				n++;
			}
		}
		selectWindow(dst);
		Table.set("Positive [" + channel_names[c]  + "]", row, n);
	}

	// references counts
	for (c = 0; c < references.length; c++) {
		selectWindow(src);
		x = Table.getColumn("Positive [" + references[c]  + "]");
		n = 0;
		for (i = 0; i < x.length; i++) {
			if (x[i]==1) {
				n++;
			}
		}
		selectWindow(dst);
		Table.set("Positive [" + references[c]  + "]", row, n);
	}

	// count codes counts
	for (c = 0; c < codes.length; c++) {
		s = parseCode(codes[c]);
		selectWindow(src);
		x = newArray(Table.size);
		Array.fill(x, 1);
		for (k = 0; k < s.length / 2; k++) {
			y = Table.getColumn("Positive [" + s[2*k]  + "]");
			for (i = 0; i < x.length; i++) {
				if (y[i] != s[2*k+1]) {
					x[i] = 0;
				}
			}
		}
		n = 0;
		for (i = 0; i < x.length; i++) {
			if (x[i] > 0) {
				n++;
			}
		}
		selectWindow(dst);
		Table.set("Positive [" + codes[c] + "]", row, n);
	}

	// average distance to other labels if positive
	for (c1 = 0; c1 < references.length; c1++) {
		for (c2 = 0; c2 < codes.length; c2++) {
			selectWindow(src);
			x = Table.getColumn("Positive [" + references[c1]  + "]");
			y = Table.getColumn("Distance to [" + codes[c2]  + "] in " + pixel_unit);
			n = 0;
			d = 0;
			for (i = 0; i < x.length; i++) {
				if (x[i]==1) {
					n++;
					d += y[i];
				}
			}
			selectWindow(dst);
			Table.set("Average distance [" + references[c1]  + "|" + codes[c2] + "] in " + pixel_unit, row, d/n);
		}
	}
	Table.update;
}

function cropActiveSelection() {
	/*
	 * Crop the image using the active selection if there is one.
	 * The ROI or the all image is added to ROI manager as "Selection".
	 *
	 */

	if (Roi.size == 0) {
		run("Select All");
		roiManager("add");
	} else {
		run("Crop");
		roiManager("add");
	}
	roiManager("select", 0);
	roiManager("rename", "Selection");
}

function parseCSVString(csv) {
	/*
	 * Parse a csv string and return the elements
	 *
	 * Input:
	 *	csv: string with comma separate entries
	 *
	 * Output:
	 *  array with values as strings
	 */
	str = split(csv,",");
	values = newArray(str.length);
	for (i = 0 ; i < str.length; i++) {
		values[i] = String.trim(str[i]);
	}
	return values;
}

function equalizeChannels(id) {
 	/*
 	 *  Equalize all channels (enhance contrast)
 	 *
 	 *  Input
 	 *    id: id of the window
 	 *
 	 *  Output:
 	 *    Equalized image
 	 */
 	selectImage(id);
 	 run("Select None");
 	for (c = 1; c <= nSlices; c++) {
 		Stack.setChannel(c);
 		run("Enhance Contrast", "saturated=0.15");
 	}
 }

function closeWindow(name) {
 	if (isOpen(name)) {
 		selectWindow(name);
 		run("Close");
 	}
 	run("Collect Garbage");
}

function closeImageList(list) {
	for (i = 0 ;i < list.length; i++) {
		selectImage(list[i]);
		close();
	}
	run("Collect Garbage");
}

function addROIsToOverlay(id, rois) {
	selectImage(id);
	n = roiManager("count");
	for (i = 0; i < n; i++) {
		roiManager("select", i);
		run("Add Selection...");
		Overlay.setStrokeColor("white");
	}
}

function createTestImageOld() {
	/*
	 * Create a 1024x1024 4 channels test image
	 * with 12x12 cells
	 */

	run("Close All");
	n = 1024; // image size
	nb = 12; // number of position in the grid
	d = 40; // diameter
	newImage("HyperStack", "32-bit color-mode", n, n, 4, 1, 1);
	probas =  newArray(1,0.1,0.2,0.2);
	for (i = 0; i < nb; i++) {
		for (j = 0; j < nb; j++) {
			for (k = 0; k < 4; k++) if (random < probas[k]) {
				Stack.setChannel(k+1);
				setColor(255);
				if (k==0) {
					makeOval((i+0.15+0.3*random)*n/nb, (j+0.15+0.3*random)*n/nb, d, d);
				} else {
					makeRectangle(i*n/nb+3, j*n/nb+3, n/nb-10, n/nb-10);
				}
				fill();
			}
		}
	}
	run("Select None");
	run("Gaussian Blur...", "sigma=5 stack");
	luts = newArray("Blue","Green","Yellow","Red");
	for (c = 1; c <= 4; c++) {
		Stack.setChannel(c);
		resetMinAndMax();
	}
	run("8-bit");

	Stack.setDisplayMode("composite");
	for (c = 1; c <= 4; c++) {
		Stack.setChannel(c);
		run(luts[c-1]);
	}
}

function multinomial(p) {
	/*
	 * Multinimial random variate generation
	 *
	 * Input
	 *  p (array): probabilities (sum to 1)
	 *
	 * Output
	 *  randomly distributed variable
	 */
	x = random;
	s = 0;
	for (i = 0; i < p.length; i++) {
		s += p[i];
		if (s > x) {
			return i;
		}
	}
	return p.length-1;
}


function createTestImage() {
	/*
	 * Create a test image with 4 channels
	 *
	 */

	run("Close All");
	d = 40; // diameter
	nb = 6; // number of position in the grid
	n = 512; // image size
	w = 0.5; // wiggle nuclei position
	newImage("nuc", "8-bit black", n, n, 1);

	for (i = 0; i < nb; i++) {
		for (j = 0; j < nb; j++) {
			makeOval((i+0.15+w*random)*n/nb, (j-0.5+0.5*(i%2)+0.15+w*random)*n/nb, d*(1+0.3*random), d*(1+0.3*random));
			fill();
		}
	}

	setThreshold(128, 255);
	run("Convert to Mask");
	run("Connected Components Labeling", "connectivity=4 type=[16 bits]");
	selectImage("nuc");
	run("Invert");
	run("Distance Map");
	run("Marker-controlled Watershed", "input=[nuc] marker=nuc-lbl mask=None compactness=0 binary calculate use");
	run("16-bit");
	run("Remap Labels");
	rename("cells");
	createROIfromLabels(getImageID());

	selectImage("nuc-lbl");
	close("nuc-lbl");
	close("EDM of test");
	close("cells");
	close("EDM of nuc");


	newImage("test", "32-bit grayscale-mode", n, n, 4, 1, 1);
	id = getImageID();
	selectWindow("nuc");
	run("Select None");
	setThreshold(0, 1);
	run("Create Selection");

	selectWindow("test");
	Stack.setChannel(1);
	run("Select None");
	run("Restore Selection");
	setColor(255);
	fill();
	run("Select None");

	// define the probabilities for each class
	probas =  newArray(0.2,0.3,0.3,0.2);

	// define the channels for each class
	class_channel = newArray(1,0,0,
							 0,1,0,
							 0,0,1,
							 0,1,1);

	// draw the cells with their class
	for (i = 0; i < roiManager("count"); i++) {
		roiManager("select", i);
		class = multinomial(probas);
		for (c = 2; c <= 4; c++) {
			if (class_channel[class*3+(c-2)] == 1) {
				Stack.setChannel(c);
				makeOval(getValue("X")-d/4, getValue("Y")-d/4, d/2, d/2);
				fill();
				roiManager("select", i);
				run("Gaussian Blur...", "sigma="+1.5*d);
			}
		}
	}

	run("Select None");
	run("Gaussian Blur...", "sigma=2 stack");
	Stack.getStatistics(voxelCount, mean, min, max, stdDev);
	run("Add Specified Noise...", "standard="+0.001*max+" stack");

	for (c = 1; c <= 4; c++) {
		Stack.setChannel(c);
		resetMinAndMax();
	}
	run("8-bit");

	luts = newArray("Blue","Green","Yellow","Red");
	Stack.setDisplayMode("composite");
	for (c = 1; c <= 4; c++) {
		Stack.setChannel(c);
		run(luts[c-1]);
	}
	selectWindow("ROI Manager");
	run("Close");
	selectWindow("nuc");
	close();
}
