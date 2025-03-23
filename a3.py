import itertools
import math
from mip import Model, xsum, BINARY, CONTINUOUS, minimize

m = Model()

# x1..x4 = binary
x = [m.add_var(var_type=BINARY) for i in range(4)]
# x5..x12 = continuous >= 0
for i in range(8):
    x.append(m.add_var(var_type=CONTINUOUS, lb=0))

# cost = 100*x1 +120*x2 +90*x3 +150*x4 + x5 +2*x6 + ...
coeffs = [100,120,90,150,  1,2,1,2,  1,2,1,2]

m.objective = minimize(xsum(coeffs[i]*x[i] for i in range(12)))

# Constraints:
# (1) x1 + x2 + x3 + x4 >= 2
m.add_constr(xsum(x[i] for i in range(4)) >= 2)
# (2) x5 + x6 + x7 + x8 >= 56
m.add_constr(xsum(x[i] for i in range(4,8)) >= 56)
# (3) x9 + x10 + x11 + x12 >= 74
m.add_constr(xsum(x[i] for i in range(8,12)) >= 74)
# (4) -40x1 + x5 + x9 <= 0
m.add_constr(-40*x[0] + x[4] + x[8] <= 0)
# (5) -60x2 + x[5] + x[9] <= 0
m.add_constr(-60*x[1] + x[5] + x[9] <= 0)
# (6) -50x3 + x[6] + x[10] <= 0
m.add_constr(-50*x[2] + x[6] + x[10] <= 0)
# (7) -70x4 + x[7] + x[11] <= 0
m.add_constr(-70*x[3] + x[7] + x[11] <= 0)

# Solve
m.optimize()

if m.num_solutions:
    print("Optimal objective = ", m.objective_value)
    print("Solution: ", [v.x for v in x])
