\l svm.q
assert:{if[not x~y;'`fail]}
.svm.set_print_string_function `
.svm.version
assert[s] .svm.write_problem prob:.svm.read_problem s:read0 `heart_scale
assert[::] .svm.check_parameter[prob] param:.svm.defparam[prob] .svm.param
assert[prob] .svm.prob_inout prob
m1:.svm.train[prob;param]
m2:.svm.load_model `heart_scale.model
do[1000;m:.svm.load_model `heart_scale.model]
assert[m] {.svm.save_model[`model] x;m:.svm.load_model[`model];system "rm model";m} m
do[1000;param ~ .svm.param_inout param]
assert[m] .svm.model_inout m
do[1000;.svm.model_inout m]
avg prob.y=.svm.cross_validation[prob;param;2i]
.svm.check_probability_model m
avg prob.y=.svm.predict[m] each prob.x
.svm.predict_probability[m] each prob.x
.svm.predict_values[m] each prob.x