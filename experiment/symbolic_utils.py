import ast
import os
import pdb
import re

import numpy as np
import pandas as pd

# import simplify_utils
from read_file import read_features, read_file
from yaml import Loader, load

import sympy as sp


###############################################################################
# fn definitions from the algorithms, written in sympy operators
def sub(x, y):
    return sp.Add(x, -y)


# def division(x,y):
#     print('division')
#     if isinstance(y, sp.Float):
#         if abs(y) < 0.00001:
#             return x
#             # result = sp.Mod(x,1e-6+abs(y))
#             # if y < 0:
#             #     result = -result
#             # return result
#     return sp.Mul(x,1/y)


# TODO: handle protected division
def div(x, y):
    return sp.Mul(x, 1 / y)


def square(x):
    return sp.Pow(x, 2)


def cube(x):
    return sp.Pow(x, 3)


def quart(x):
    return sp.Pow(x, 4)


# def PLOG(x, base=None):
#     if isinstance(x, sp.Float):
#         if x < 0:
#             x = sp.Abs(x)
#     if base:
#         return sp.log(x, base)
#     else:
#         return sp.log(x)


def PLOG(x):
    if isinstance(x, sp.Float):
        if x < 0:
            x = sp.Abs(x)
    return sp.log(x)


def PLOG10(x):
    if isinstance(x, sp.Float):
        if x < 0:
            x = sp.Abs(x)
    return sp.log(x, base=10)


def PSQRT(x):
    if isinstance(x, sp.Float):
        if x < 0:
            return sp.sqrt(sp.Abs(x))
    return sp.sqrt(x)


###############################################################################


def complexity(expr):
    c = 0
    for arg in sp.preorder_traversal(expr):
        c += 1
    return c

    # def round_to_first_non_zero_decimal_place(num):
    #     # Find the number of decimal places to keep
    #     decimal_place = 0
    #     while True:
    #         if abs(round(num, decimal_place)) > 0:
    #             break
    #         decimal_place += 1
    #     return round(num, decimal_place)

    # def round_floats(expr_str):
    #     def round_numbers(match):
    #         num = float(match.group(0))
    #         # Check if the absolute value of the number is less than 0.0005
    #         if abs(num) < 0.0005:
    #             return match.group(0)  # Return the original number as-is
    #         else:
    #             return f"{num:.3f}"  # Round to 3 decimal places otherwise

    #     # Regular expression to match floats in the expression
    #     float_pattern = r"[-+]?\b\d+\.\d+\b"

    #     # Replace floats in the expression with rounded values (if applicable)
    #     rounded_expr_str = re.sub(float_pattern, round_numbers, expr_str)

    #     return rounded_expr_str

    # def round_floats_sympy(expr):
    #     def round_numbers(expr):
    #         if isinstance(expr, (sp.Float, sp.Integer, sp.Rational)):
    #             num = float(expr)
    #             # Check if the absolute value of the number is less than 0.0005
    #             if abs(num) < 0.0005:
    #                 # Round to the first non-zero decimal place
    #                 rounded_num = round_to_first_non_zero_decimal_place(num)
    #                 return sp.Float(rounded_num)
    #             else:
    #                 return round(expr, 3)  # Round to 3 decimal places otherwise
    #         elif isinstance(expr, sp.Symbol):
    #             return expr
    #         elif isinstance(expr, sp.Expr):
    #             # Recursively traverse the expression tree
    #             args = [round_numbers(arg) for arg in expr.args]
    #             return expr.func(*args)
    #         else:
    #             return expr

    #     # Round the numerical constants in the expression
    #     rounded_expr = round_numbers(expr)

    return rounded_expr


################################################################################
# currently the MRGP model is put together incorrectly. this set of functions
# corrects the MRGP model form so that it can be fed to sympy and simplified.
################################################################################
def add_commas(model):
    return "".join([m + "," if not m.endswith("(") else m for m in model.split()])[:-1]


def decompose_mrgp_model(model_str):
    """split mrgp model into its betas and model parts"""
    new_model = []
    # get betas
    betas = [
        float(b[0])
        for b in re.findall(r"[+-]?(\d+(\.\d*)?|\.\d+)([eE][+-]?\d+)?\*", model_str)
    ]
    # print("betas:", betas)
    # get form
    submodel = re.sub(
        pattern=r"[+-]?(\d+(\.\d*)?|\.\d+)([eE][+-]?\d+)?\*", repl=r"", string=model_str
    )
    return betas, submodel  # new_model


def print_model(node):
    if hasattr(node, "func"):
        model_str = node.func.id + "("
    elif hasattr(node, "id"):
        # model_str = node.id
        return node.id
    else:
        pdb.set_trace()
    if hasattr(node, "args"):
        i = 0
        for arg in node.args:
            model_str += print_model(arg)
            i += 1
            if i < len(node.args):
                model_str += ","
        model_str += ")"

    # print('print_model::',model_str)
    return model_str


def add_betas(node, betas):
    beta = betas[0]
    betas.pop(0)
    if float(beta) > 0:
        model_str = str(beta) + "*" + print_model(node)
        i = 1
    else:
        # print('filtering fn w beta=',beta)
        model_str = ""
        i = 0
    if hasattr(node, "args"):
        for arg in node.args:
            submodel = add_betas(arg, betas)
            if submodel != "":
                model_str += "+" if i != 0 else ""
                model_str += submodel
                i += 1
    # print('add_betas::',model_str)
    return model_str


################################################################################
def replace_patterns_1(string):
    # Define the regular expression pattern
    # X[number] or x[number]
    # X[:,number] or x[:,number]
    pattern = r"(x|X)(\[|\[\:\,)(\d+)(\])"

    # Define a function to replace the matched pattern with 'X_' followed by the number
    def replace(match):
        return "X_" + match.group(3)

    # Use re.sub() function to replace all occurrences of the pattern in the string
    replaced_string = re.sub(pattern, replace, string)

    return replaced_string


def replace_patterns_2(string):
    # Define the regular expression pattern x_number
    pattern = r"(x)(\_)(\d+)"

    # Define a function to replace the matched pattern with 'X_' followed by the number
    def replace(match):
        return "X_" + match.group(3)

    # Use re.sub() function to replace all occurrences of the pattern in the string
    replaced_string = re.sub(pattern, replace, string)

    return replaced_string


def replace_patterns_3(string):
    # Define the regular expression pattern
    # xnumber
    pattern = r"(x|X)(\d+)"

    # Define a function to replace the matched pattern with 'X_' followed by the number
    def replace(match):
        return "X_" + match.group(2)

    # Use re.sub() function to replace all occurrences of the pattern in the string
    replaced_string = re.sub(pattern, replace, string)

    return replaced_string


def zero_to_one_idx(input_string):
    pattern = r"\bX_(\d+)\b"

    def replace(match):
        num = int(match.group(1))
        return f"X_{num + 1}"

    return re.sub(pattern, replace, input_string)


def find_vars_idx(input_string):
    # Define the regex pattern with capturing group for digits
    pattern = r"\bX_(\d+)\b"

    # Find all matches in the input string
    matches = re.findall(pattern, input_string)

    # Convert the matched strings to integers
    idx = [int(match) for match in matches]
    idx = list(set(idx))  # Remove duplicates
    idx = sorted(idx)

    return idx


def clean_pred_model(model_str, dataset, est_name, og_data=False, digits=4):
    if model_str.strip() == "":
        print("empty model...")
        return ""

    mrgp = "MRGP" in est_name

    model_str = model_str.strip()

    if mrgp:
        model_str = model_str.replace("+", "add")
        model_str = add_commas(model_str)
        betas, model_str = decompose_mrgp_model(model_str)

    # X, labels, features = read_file(dataset)
    # print("reading features")
    features = read_features(os.path.dirname(dataset) + "/metadata.yaml")
    if og_data:
        features = np.array([c for c in features if "x_bad" not in c])

    local_dict = {k: sp.Symbol(k, positive=True) for k in features}

    # Clean up model_str
    # print("replacing patterns")
    model_str = replace_patterns_1(model_str)
    model_str = replace_patterns_2(model_str)
    model_str = replace_patterns_3(model_str)
    new_model_str = model_str
    # print("model_str: ", model_str)

    # rename features
    if any([n in est_name.lower() for n in ["mrgp", "operon", "dsr"]]):
        for i, f in enumerate(features):
            pat = r"\bX" + "_" + str(i + 1) + r"\b"
            new_model_str = re.sub(pat, f, new_model_str)
    else:
        for i, f in enumerate(features):
            pat = r"\bX" + "_" + str(i) + r"\b"
            new_model_str = re.sub(pat, f, new_model_str)

    # operators
    new_model_str = new_model_str.replace("^", "**")
    # GP-GOMEA
    new_model_str = new_model_str.replace("p/", "/")
    new_model_str = new_model_str.replace("plog", "PLOG")
    new_model_str = new_model_str.replace("aq", "/")
    # MRGP
    new_model_str = new_model_str.replace("mylog", "PLOG")
    # ITEA
    new_model_str = new_model_str.replace("sqrtAbs", "PSQRT")
    # new_model_str = re.sub(pattern=r'sqrtAbs\((.*?)\)',
    #        repl=r'sqrt(abs(\1))',
    #        string=new_model_str
    #       )
    new_model_str = new_model_str.replace("np.", "")
    # ellyn & FEAT
    new_model_str = new_model_str.replace("|", "")
    new_model_str = new_model_str.replace("log", "PLOG")
    new_model_str = new_model_str.replace("sqrt", "PSQRT")

    # AIFeynman
    new_model_str = new_model_str.replace("pi", "3.1415926535")

    local_dict.update(
        {
            "add": sp.Add,
            "mul": sp.Mul,
            "max": sp.Max,
            "min": sp.Min,
            "sub": sub,
            "div": div,
            "square": square,
            "cube": cube,
            "quart": quart,
            "PLOG": PLOG,
            "PLOG10": PLOG,
            "PSQRT": PSQRT,
        }
    )
    # BSR
    # get rid of square brackets
    new_model_str = new_model_str.replace("[", "(").replace("]", ")")

    # print("parsing", new_model_str)
    if mrgp:
        mrgp_ast = ast.parse(new_model_str, "", "eval")
        new_model_str = add_betas(mrgp_ast.body, betas)
        assert len(betas) == 0

    # print("cleaned...")
    # print("round_floats")
    # new_model_str = round_floats(new_model_str)
    # print("cleaned model:", new_model_str)
    model_sym = sp.parse_expr(new_model_str, local_dict=local_dict)
    model_sym_rounded = model_sym.xreplace(
        {
            n: n.round(digits) if abs(n) >= 5 * 10 ** (-(digits + 1)) else n
            for n in model_sym.atoms(sp.Float)
        }
    )

    # if simplify:
    #     # print("simplifying...")
    #     model_sym_simplified = sp.simplify(model_sym_rounded, ratio=ratio)
    #     # print("simplified model:", model_sym)
    #     return model_sym_simplified
    # else:
    #     return model_sym_rounded
    return model_sym_rounded


def symplify_model(model_str, dataset, digits=4):
    features = read_features(os.path.dirname(dataset) + "/metadata.yaml")
    features = np.array([c for c in features if "x_bad" not in c])
    model_str = model_str.replace("pi", "3.1415926535")

    local_dict = {k: sp.Symbol(k, positive=True) for k in features}
    model_sym = sp.parse_expr(model_str, local_dict=local_dict)
    # Note: `symbolic_model_cleaned` and `true_model` are already rounded
    # model_sym_rounded = model_sym.xreplace(
    #     {
    #         n: n.round(digits) if abs(n) >= 5 * 10 ** (-(digits + 1)) else n
    #         for n in model_sym.atoms(sp.Float)
    #     }
    # )

    return model_sym


def get_sym_model(dataset, return_str=True, og_data=False, digits=4):
    """return sympy model from dataset metadata"""
    metadata = load(
        open("/".join(dataset.split("/")[:-1]) + "/metadata.yaml", "r"), Loader=Loader
    )
    df = pd.read_csv(dataset, sep="\t")
    features = [c for c in df.columns if c != "target"]
    if og_data:
        features = [c for c in features if "x_bad" not in c]
    # print('features:',df.columns)
    description = metadata["description"].split("\n")
    model_str = [ms for ms in description if "=" in ms][0].split("=")[-1]
    model_str = model_str.replace("pi", "3.1415926535")
    if return_str:
        return model_str

    # print(features)

    # pdb.set_trace()
    # handle feynman problem constants
    #     print('model:',model_str)
    # model_str = round_floats(model_str)
    model_sym = sp.parse_expr(model_str, local_dict={k: sp.Symbol(k) for k in features})
    model_sym_rounded = model_sym.xreplace(
        {
            n: n.round(digits) if abs(n) >= 5 * 10 ** (-(digits + 1)) else n
            for n in model_sym.atoms(sp.Float)
        }
    )
    #     print('sym model:',model_sym)
    return model_sym_rounded


def rewrite_AIFeynman_model_size(model_str):
    """AIFeynman complexity was incorrect prior to version , update it here"""
    return complexity(sp.parse_expr(model_str))
