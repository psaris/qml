\l linear.q
assert:{if[not x~y;'`fail]}
.linear.set_print_string_function `
.linear.version
assert[s] .linear.write_problem prob:.linear.read_problem s:read0 `heart_scale
assert[::] .linear.check_parameter[prob] param:.linear.defparam[prob] .linear.param
assert[prob] .linear.prob_inout prob
m1:.linear.train[prob;param]
m2:.linear.load_model `heart_scale.model
do[1000;m:.linear.load_model `heart_scale.model]
assert[m] {.linear.save_model[`model] x;m:.linear.load_model[`model];system "rm model";m} m
do[1000;param ~ b:.linear.param_inout param]
assert[m] .linear.model_inout m
do[1000;.linear.model_inout m]
avg prob.y=.linear.cross_validation[prob;param;2i]
.linear.find_parameter_C[prob;param;2i;1f;1e10]
.linear.check_probability_model m
avg prob.y=.linear.predict[m] each prob.x
.linear.predict_probability[m] each prob.x
.linear.predict_values[m] each prob.x