function [vals,ids] = findnearest(xs,target,n)
arguments
	xs
	target
	n = 1
end
	
	% finite_index = isfinite(xs);
	% finite_start = find(finite_index,1,"first");
	% finite_end   = find(finite_index,1,"last");
	% xsF = xs(finite_start:finite_end);
	% val = interp1(xsF,xsF,target,'nearest');
	% idx = find(xs == val);

	%% Another alternative approach
	[~,ids] = sort(abs(xs-target));
	ids = ids(1:n);
	vals = xs(ids);

	% % Set a tolerance based on largest difference between elements
	% dx1 = max(abs(diff(xs))+eps(target))/2;
	% idx1 = find(abs(xs-target) < dx1);
	% vals = xs(idx1);
	% 
	% if length(vals) <= n
	% 	ids = idx1;
	% else
	% 	dx2 = max(abs(diff(vals))+eps(target))/2;
	% 	ids = find(abs(xs-target) < dx2);
	% 	vals = xs(ids);
	% end
	

end