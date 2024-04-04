%% fanout_crystal_setup.m
% Template for configuration of poled crystals with fanout grating
% structure.
%
%	Will need to implement a way for Crystal object to store fanout grating
%	information such that the model can utilise a transverse displacement
%	distance and calculate a new grating period on demand.
%
%	Sebastian C. Robarts 2024 - sebrobarts@gmail.com

clear
close all

%% General Optic arguments
% If only one surface is specified, it's assumed that the same coating
% exists on each surface.
coating_str = "HCP_PPLN_Fanout_AR" ; % To be extracted from the HCP pdf as supplied by Chromacity
% coating_str = 'AR';	% Idealised 100% anti-reflection across all wavelengths
temp_C = 34;
L = 5e-3;
name = "HCP_PPLN_fanout_Chromacity";

%% Crystal specific arguments
% Fanout grating function arguments:
P1 = 27.5e-6;	% Starting grating period [m]
P2 = 32.5e-6;	% Finishing grating period [m]
xtal_height = 6.5e-3;	% Quoted y dimension [m], fanout poling may not extend this full distance?	
% a = 0.48;		% Exponent for rate of chirp

uncertainty_m = 0.2e-6;	% Small perturbation in domain wall locations [m]
dutyOff = 0;	% Systematic offset of duty cycle within each period (not currently implemented for chirped)
grating_m = [P1; P2];
y = 3.5e-3;
mfd = 36.3e-6;	% Mode Field Diameter [m]

xtalArgs = {grating_m, uncertainty_m, dutyOff};

PPLN = NonlinearCrystal(xtalArgs{:},coating_str,"PPLN",L);
PPLN.Height = xtal_height;
PPLN.VerticalPosition = y;
PPLN.ModeFieldDiameter = mfd;
PPLN.Bulk.Temperature = temp_C;



% Create a simulation window object using a default time window since we're
% only interested in spectral information here
points = 2^14;
lam0 = 1040e-9;
wavelims = [350 6500];
tOff =  1 * -1.25e-12;

lamWin = SimWindow(lam0,points,wavelims,tOff,"wavelims");

%% Initialise Laser / Input Pulse
load("Chromacity_230042_9A.mat");

% laser.SourceString = 'Sech';

cav = Cavity(PPLN,0);
errorBounds = [5e-2,1e0];	% Percentage error tolerance
minStep = 0.20e-6;		% Minimum step size
optSim = OpticalSim(laser,cav,lamWin,errorBounds,minStep);
optSim.RoundTrips = 1;
optSim.ProgressPlots = 3;
optSim.ProgressPlotting = 0;
optSim.setup;

laser.Pulse.plot;

% PPLN.store(name,1);
PPLN.plot;
PPLN.xtalplot([1350 1800]);
PPLN.fanoutplot([1350 1800],3000);