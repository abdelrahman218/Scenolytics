import User from "../models/user.js";
import jwt from "jsonwebtoken";

const JWT_SECRET = process.env.JWT_SECRET;

export const signUpRequiredFieldsValidator = (req, res, next) => {
  const { name, email, password, gender, age, role } = req.body;
    if (!name || !email || !password || !role) {
        return res.status(400).json({
            message: "name, email, password, and role are required",
        });
    }

    if(role == 'actor' && (!age || !gender)){
        return res.status(400).json({
            message: "age and gender are required",
        });
    }

    next();
};

export const emailPasswordValuesValidator = (req, res, next) =>{
    const { email, password } = req.body;
    
    const emailRegex = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/;

    if(!emailRegex.test(email)){
        return res.status(422).json({
            message: "Invalid Email"
        });
    }

    const passwordRegex = /^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d]{8,}$/;

    if(!passwordRegex.test(password)){
        return res.status(422).json({
            message: "Invalid password (At least 8 characters, At least one letter, At least 1 digit)"
        });
    }
    
    next();

};

export const signUpValuesValidator = (req, res, next) => {
    const { name, age, gender, role } = req.body;

    const nameRegex = /^[a-zA-Z]+(?:[\s-'][a-zA-Z]+)*$/;
    const roleValues = ['actor','director'];
    const genderValues = ['Male', 'Female'];

    if(!nameRegex.test(name)){
        return res.status(422).json({
            message: "Invalid name"
        });
    }

    if (!roleValues.includes(role)){
        return res.status(422).json({
            message: "Invalid role"
        });
    }

    if(age && (age<8 || age>120 )){
        return res.status(422).json({
            message: "Invalid age"
        });
    }

    if(gender && (!genderValues.includes(gender))){
        return res.status(422).json({
            message: "Invalid gender"
        });
    }
    
    next();

};

export const logInRequiredFieldsValidator = (req, res, next) => {
  const { email, password } = req.body;
    if (!email || !password) {
        return res.status(400).json({
            message: "email and password are required",
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
        const decoded = jwt.verify(token, JWT_SECRET);
        req.user = decoded;
        next();
    } catch (error) {
        return res.status(401).json({
            message: "Invalid or expired token",
        });
    }
};