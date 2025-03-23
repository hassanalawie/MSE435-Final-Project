function [xOpt, fval, exitflag, output, dualVariables] = solve_rmp_lp(costVector, sigmaMatrix)
    c = costVector;                
    Aeq = sigmaMatrix;             
    beq = ones(size(Aeq,1),1);      
    lb  = zeros(size(c));           
    ub  = ones(size(c));             

    [xOpt, fval, exitflag, output, lambda] = linprog(c, [], [], Aeq, beq, lb, ub);

    dualVariables = -lambda.eqlin;  % Dual variables for equality constraints
end