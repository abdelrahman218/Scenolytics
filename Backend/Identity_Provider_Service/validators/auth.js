import User from "../models/user.js";
import jwt from "jsonwebtoken";

const JWT_SECRET = process.env.JWT_SECRET;

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

export const validateJWTToken = (req, res, next) => {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
        return res.status(401).json({
            message: "Authorization header missing or malformed",
        });
    }
    const token = authHeader.split(" ")[1];
    try {
        jwt.verify(token, JWT_SECRET);
        next();
    } catch (err) {
        return res.status(401).json({
            message: "Invalid or expired token",
        });
    }
};