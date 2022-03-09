import os
import numpy as np
import SimpleITK as sitk
import glob
import argparse
import math
import sys

parser = argparse.ArgumentParser(description='Threshold Mask.' )
parser.add_argument( '-i', type=str, required=True )
parser.add_argument( '-o', type=str, required=True )
args = vars(parser.parse_args())

iPth = args['i']
oPth = args['o']

mask = sitk.ReadImage(iPth)
sMask = sitk.GetArrayFromImage(mask)

sMask1 = np.zeros(sMask.shape)
sMask1[sMask>0]=1

mask1 = sitk.GetImageFromArray(sMask1)

mask1.CopyInformation(mask)
sitk.WriteImage(mask1,oPth)
