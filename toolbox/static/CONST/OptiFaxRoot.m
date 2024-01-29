function pathstr = OptiFaxRoot(devFlag)
arguments
	devFlag = 0;
end
if devFlag
	pathstr = pwd;
else
	addonPath = matlab.internal.addons.util.retrieveAddOnsInstallationFolder;
	pathstr = addonPath + filesep + 'Toolboxes' + filesep + 'OptiFax';
end
end