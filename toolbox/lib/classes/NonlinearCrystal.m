classdef NonlinearCrystal < Waveguide
	%NONLINEARCRYSTAL A non-centrosymmetric crystal gain medium
	%   Inherits the Waveguide (Optic) class and extends it to allow crystal
	%   specific methods, like the bulk of the OPO simulation.
	%
	%	Sebastian C. Robarts 2023 - sebrobarts@gmail.com

	properties
		GratingPeriod
		Uncertainty
		DutyCycleOffset
		StepSize = 1e-7;
		Height = 1;				% Int for stepped, [m] for fanout.
		VerticalPosition = 1;	% Int for stepped, [m] for fanout.
	end
	properties (Transient)
		OptSim
		Polarisation
		DomainWidths
		Periods
		DomainWallPositions
		NSteps
	end
	properties (Dependent)
		TStepShift
		Z
	end

	methods

		function obj = NonlinearCrystal(grating_m,uncertainty_m,dutyOff,varargin)
			%NONLINEARCRYSTAL Construct an instance of this class
			% Calls the Optic constructor and then automatically
			% assigns Chi2 based on material.
			
			% Allow for recasting an existing optic as a nonlinear crystal
			% if class(varargin{1})=="Optic"||class(varargin{1})=="NonlinearCrystal" 
			if isa(varargin{1},"Optic")
				opt = varargin{1};
				% optArgs{1} = opt.Regime;
				optArgs{1} = opt.S1;
				optArgs{2} = opt.Bulk;
				[optArgs{3:4}] = deal({});
				optArgs{5} = opt.S2;
			else
				optArgs = varargin;
			end
			% Superclass constructor call, which can't be conditional
			obj@Waveguide(optArgs{:});

			switch obj.Bulk.Material
				case {"PPLN","LN_e","LN_o"}
					obj.Chi2 = 27e-12;
				case {"OP-GaP","OPGaP"}
					obj.Chi2 = 70e-12;
				otherwise
					obj.Chi2 = 0e-12;
			end
			% if strcmp(obj.Bulk.Material,"PPLN")
			% 	obj.Chi2 = 2*26e-12;
			% end
			obj.GratingPeriod = grating_m;
			obj.Uncertainty = uncertainty_m;
			obj.DutyCycleOffset = dutyOff;
		end

		function simulate(obj,simWin)
			simulate@Waveguide(obj,simWin);
			L_m = obj.Bulk.Length;
			obj.NSteps = floor(L_m / obj.StepSize);

			obj.pole;
		end

		function ppole(obj,optSim)
			obj.OptSim = optSim;
			L_m = obj.Bulk.Length;
			obj.NSteps = floor(L_m / optSim.StepSize);
			
			obj.pole;
		end

		function pole(obj)
			L_m = obj.Bulk.Length;
			if isnumeric(obj.GratingPeriod)
				n = length(obj.GratingPeriod);
				switch n
					case 1
						grating = obj.GratingPeriod;
					case 2
						grating = obj.fanout;
					otherwise
						obj.Height = uint8(n);
						obj.VerticalPosition = uint8(obj.VerticalPosition);
						grating = obj.GratingPeriod(obj.VerticalPosition);
				end
			else
				grating = obj.GratingPeriod;
			end
			
			xtal = QPMcrystal(obj.NSteps,L_m,grating,...
										 obj.Uncertainty,...
										 obj.DutyCycleOffset);

			obj.Polarisation = xtal.P .* 2 .* obj.Chi2;
			obj.DomainWidths = xtal.domains;
			obj.DomainWallPositions = xtal.walls;
			obj.Periods = xtal.periods;
		end

		function grating = fanout(obj)
			P1 = obj.GratingPeriod(1);
			P2 = obj.GratingPeriod(2);
			h = obj.Height;
			dgdy = (P2-P1)/h;
			y = obj.VerticalPosition;

			grating = P1 + (dgdy*y);
		end
		
		function tss = get.TStepShift(obj)
			ts = obj.Transmission .^ (1/obj.NSteps);
			tss = fftshift(ts);
		end

		function z = get.Z(obj)
			dz = obj.Length/(obj.NSteps-1);
			z = 0:dz:obj.Length;
		end

		%% Plotting
		function scanplot(obj,sigrange,n_pos,beam_str,axs)
			arguments
				obj
				sigrange
				n_pos
				beam_str = "Signal";
				axs = 0;
			end
			% n_pos = 5;
			[gain,~,signal,idler] = qpmgain(obj,obj.OptSim.PumpPulse,sigrange);
			if strcmp(beam_str,"Signal")
				sig_unique = signal(:,1);
			elseif strcmp(beam_str,"Idler")
				sig_unique = idler(:,1);
			end
			gain_sum = single(zeros(n_pos,length(gain(:,1))));

			if isinteger(obj.Height)
				ys = 1:n_pos;
			else
				ys = linspace(0,obj.Height,n_pos);
			end
		
			for n = 1:n_pos
				obj.VerticalPosition = ys(n);
				obj.pole;

				[gain] = qpmgain(obj,obj.OptSim.PumpPulse,sigrange);
				gain_sum(n,:) = sum(gain,2);
				disp(['Step ', num2str(n) ,' complete'])
			end

			if isinteger(obj.Height)
				ys = obj.GratingPeriod;
			end

			if ~isgraphics(axs,"axes")
				fh = figure("Position",[100 100 800 600]);
				axs = axes(fh);
			end
			if isinteger(obj.Height)
				p = waterfall(axs,sig_unique,ys,gain_sum);
					view(-0.01,30);
					p.EdgeColor ='k';
					p.LineWidth = 1.25;
					p.FaceColor="flat";
					p.FaceVertexCData = parula(n);
					p.FaceAlpha = 0.7;
					axs.Color = [1 1 1]*0.9;
					axs.GridColor = [1 1 1]*0;
					axs.MinorGridColor = [1 1 1]*0;
					grid minor

					ylabel('Grating Period / m')
			else
				imagesc(axs,sig_unique,ys*1e3,gain_sum)
					axs.YAxis.Direction = 'normal';
					colormap(axs,"turbo")
					axs.Color = [0 0 0];
					axs.GridColor = [1 1 1];
					axs.MinorGridColor = [1 1 1];
					shading("interp")
					colorbar;
					ylabel('Crystal Y Position / mm')
					ysecondarylabel("\Lambda="+num2str(obj.GratingPeriod(1)*1e6,'%.2f')...
										  +"-"+num2str(obj.GratingPeriod(2)*1e6,'%.2f')+"\mum")
					% yticks([yticks,obj.Height*1e3])
					% ytls = yticklabels;

			end
			titleStr    = "Full Temporal Overlap QPM, " ...
						+ "\chi^{(2)} = " + num2str(obj.Chi2*1e12,'%i') + "pVm^{-1}";

			subtitleStr = "L = " + num2str(obj.Length*1e3,'%.1f') + "mm, " ...
						+ "T = " + num2str(obj.Bulk.Temperature) + "\circC, " ...
						+ "\sigma(\Lambda) = " + num2str(obj.Uncertainty*1e6,'%.2f') + "\mum" ...
						+ ", DCO = " + num2str(obj.DutyCycleOffset,'%.2f');
			
			title(titleStr,subtitleStr)
			if strcmp(beam_str,"Signal")
				xlabel('Signal Wavelength / m')
			elseif strcmp(beam_str,"Idler")
				xlabel('Idler Wavelength / m')
			end
		end

		function xtalplot(obj,sigrange)
			arguments
				obj NonlinearCrystal
				sigrange = [1400 1800];	% Chosen signal limits in nm
			end
			upPoled = obj.DomainWidths(2:2:end);
			downPoled = obj.DomainWidths(1:2:end-1);
			dutyCycles = upPoled./(upPoled+downPoled);

			fh = figure;
			if isa(obj.OptSim,"OpticalSim")
				% [gain,pump,signal] = obj.gaincalc(sigrange);
				if any(obj.OptSim.Pulse.TemporalField)
					pump_optic = obj.OptSim.PumpPulse.Medium;
					pulse_optic = obj.OptSim.Pulse.Medium;
					obj.OptSim.PumpPulse.refract(obj);
					obj.OptSim.Pulse.refract(obj);
					[gain,pump,signal] = qpmgain(obj,obj.OptSim.PumpPulse,sigrange,obj.OptSim.Pulse);
					sig_unique = uniquetol(spdiags(rot90(signal,3)));
					sig_unique = sig_unique(2:end);
					gain_sum = sum(spdiags(rot90(gain,3)));
					obj.OptSim.PumpPulse.refract(pump_optic);
					obj.OptSim.Pulse.refract(pulse_optic);
				else
					[gain,pump,signal] = qpmgain(obj,obj.OptSim.PumpPulse,sigrange);
					sig_unique = signal(:,1);
					gain_sum = sum(gain,2);
				end
				tl = tiledlayout(fh,2,2);
			else
				fh.Position(4) = fh.Position(4)./2;
				tl = tiledlayout(fh,1,2);
			end
			if isinteger(obj.Height)
				titleStr = obj.Name + ", Pos = " + num2str(obj.VerticalPosition,'%i');
			else
				titleStr = obj.Name + ", Pos = " + num2str(obj.VerticalPosition*1e3,'%.2f') + "mm";
			end
			title(tl,titleStr,"Interpreter","none");
			
			nexttile
			plot(obj.DomainWallPositions,obj.DomainWidths);
			title('Poling Function')
			xlabel('z Position / m')
			ylabel('Domain Width / m')
			xlim([0 obj.Length])

			nexttile
			histogram(dutyCycles*100,11)
			title('Crystal Duty Cycle Variation')
			xlabel('Poled Period %')
			ylabel('Counts')

			if isa(obj.OptSim,"OpticalSim")
				axs = nexttile;
				surf(axs,pump,signal,gain)
				axs.YAxis.Direction = 'reverse';
				if sigrange(2)*1e-9 < max(pump,[],"all")
					zlim(axs,[0 max(gain,[],"all")]./2)
					clim(axs,[0 max(gain,[],"all")]./2)
				end
				% view(-80,30);
				view(-90,90);
				colormap(axs,"turbo")
				axs.Color = [0 0 0];
				axs.GridColor = [1 1 1];
				axs.MinorGridColor = [1 1 1];
				shading("interp")
				title('Numerical Phasematching')
				xlabel('Pump Wavelength')
				ylabel('Signal Wavelength')

				nexttile
				% plot(signal,sum(gain,2))
				plot(sig_unique,gain_sum)
				title('Full Temporal Overlap')
				xlabel('Signal Wavelength')
				ylabel('Gain, units tbc')
			end
		end

		function store(crystal,name,devFlag)
			arguments
				crystal
				name
				devFlag = 0;
			end
			crystal.Name = name;
			currentfolder = pwd;
			cd(OptiFaxRoot(devFlag));
			cd("objects" + filesep + "optics" + filesep + "crystals");
			save(name + ".mat","crystal","-mat");
			cd(currentfolder);
		end
	end

end