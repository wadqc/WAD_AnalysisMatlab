#!/usr/bin/python
# WAD2 helper for Matlab
# In older Matlab versions it takes ages to scan DICOM headers
import dicom
import json
import glob
import os
import sys

# Make it work for Python 2+3 and with Unicode
import io
try:
    to_unicode = unicode
except NameError:
    to_unicode = str


# check command line arguments
if len(sys.argv) < 2:
    print('Syntax error in wad2_dicomscanner.py. Need input data directory as argument.')

# this is where the DICOM files should be
studyDataDir = sys.argv[1]

# get present working directory, this is where the output file should go.
outputDir = os.getcwd()

try:
    os.chdir( studyDataDir )
except:
    print('Error chdir to study data dir: '+studyDataDir)
    raise


# define the study dictionary
studyInfo = { 'study': {} }

# loop over directories / series in study
i_iSeries = 1
firstInStudy = True

for dicomdir in glob.iglob("*"):
    print 'Scanning: '+dicomdir
    try:
        os.chdir( dicomdir )
    except:
        print('Error chdir to: '+dicomdir)
    else:
        # loop over files / instances in series
        i_iInstance = 1
        firstInSeries = True
        
        # define series dictionary
        seriesInfo = {}
        for dicomfile in glob.iglob("*"):
            #print "  "+dicomfile
            try:
                info = dicom.read_file(dicomfile)
            except:
                print('Error reading file as DICOM: '+dicomdir+"/"+dicomfile)
            else:
                if firstInStudy:
                    firstInStudy = False
                    try:
                        studyInfo['study']['description'] = info.StudyDescription
                    except:
                        studyInfo['study']['description'] = 'NoStudyDescription'
                    
                    studyInfo['study']['series'] = []
                
                if firstInSeries:
                    firstInSeries = False
                    # fill series dictionary
                    seriesInfo['description'] = info.SeriesDescription
                    seriesInfo['number'] = info.SeriesNumber
                    seriesInfo['instance'] = []
                
                instanceInfo = {'number': info.InstanceNumber, 'filename': studyDataDir+"/"+dicomdir+"/"+dicomfile }
                seriesInfo['instance'].append( instanceInfo )
        
        if len( seriesInfo ) > 0:
            studyInfo['study']['series'].append( seriesInfo )
        os.chdir( studyDataDir )


#print studyInfo


# Write JSON file
print 'Write input.json'
with io.open(outputDir+"/"+'input.json', 'w', encoding='utf8') as outfile:
    str_ = json.dumps(studyInfo,
                      indent=4, sort_keys=True,
                      separators=(',', ': '), ensure_ascii=False)
    outfile.write(to_unicode(str_))


# Read JSON file
#with open('input.json') as data_file:
#    studyInfoLoaded = json.load(data_file)
#
#print(studyInfo == studyInfoLoaded)

print 'Finished wad2_dicomscanner'
