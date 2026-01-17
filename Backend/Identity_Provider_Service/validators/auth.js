import User from "../models/user.js";

export const signUpRequiredFieldsValidator = (req, res, next) => {
  const { email, password, role } = req.body;
    if (!email || !password || !role) {
        return res.status(400).json({
            message: "Email, password, and role are required",
        });
    }
    next();
};

export const logInRequiredFieldsValidator = (req, res, next) => {
  const { email, password } = req.body;
    if (!email || !password) {
        return res.status(400).json({
            message: "Email and password are required",
        });
    }
    next();
};

export const checkUserExistsValidator = async (req, res, next) => {
  const { email } = req.body;
    if (await User.DoesUserExist(email)) {
        return res.status(409).json({
            message: "User with this email already exists",
        });
    }
    next();
};