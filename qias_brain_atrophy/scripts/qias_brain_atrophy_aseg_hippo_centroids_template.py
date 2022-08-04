#!/usr/bin/env python

# TODO: calculate centroids
# http://itk.org/Wiki/ITK/Examples/ImageProcessing/LabelGeometryImageFilter

import itk
import numpy as np

imageType=itk.Image[itk.US,3]

reader=itk.ImageFileReader[imageType].New()
reader.SetFileName("ASEG_FILE")
reader.Update()
aseg = reader.GetOutput()

duplicator=itk.ImageDuplicator[imageType].New()
duplicator.SetInputImage(aseg)
duplicator.Update()
aseg_singleregion=duplicator.GetOutput()
aseg_size=aseg.GetLargestPossibleRegion().GetSize()

# Left Hippocampus: 17
aseg_singleregion.FillBuffer(0)
idx_i = []
idx_j = []
idx_k = []
for i in range(0,aseg_size.GetElement(0)):
  for j in range(0,aseg_size.GetElement(1)):
    for k in range(0,aseg_size.GetElement(2)):
      if aseg.GetPixel([i,j,k]) == 17:
        aseg_singleregion.SetPixel([i,j,k],1)
        idx_i.append(i)
        idx_j.append(j)
        idx_k.append(k)
        
centroid_left_hipp = np.round([sum(idx_i)/len(idx_i), sum(idx_j)/len(idx_j), sum(idx_k)/len(idx_k)])
centroid_left_hipp = centroid_left_hipp.astype(int)

# Right Hippocampus: 53
aseg_singleregion.FillBuffer(0)
idx_i = []
idx_j = []
idx_k = []
for i in range(0,aseg_size.GetElement(0)):
  for j in range(0,aseg_size.GetElement(1)):
    for k in range(0,aseg_size.GetElement(2)):
      if aseg.GetPixel([i,j,k]) == 53:
        aseg_singleregion.SetPixel([i,j,k],1)
        idx_i.append(i)
        idx_j.append(j)
        idx_k.append(k)
        
centroid_right_hipp = np.round([sum(idx_i)/len(idx_i), sum(idx_j)/len(idx_j), sum(idx_k)/len(idx_k)])
centroid_right_hipp = centroid_right_hipp.astype(int)

# Write results to file
f = open( 'OUTPUT_FILE', 'w' )
f.write( 'LeftHippocampus ' + str(centroid_left_hipp[0]) + ' ' + 
      str(centroid_left_hipp[1]) + ' ' + 
      str(centroid_left_hipp[2]) + '\n' )
f.write( 'RightHippocampus ' + str(centroid_right_hipp[0]) + ' ' + 
      str(centroid_right_hipp[1]) + ' ' + 
      str(centroid_right_hipp[2]) + '\n' )
f.close()
