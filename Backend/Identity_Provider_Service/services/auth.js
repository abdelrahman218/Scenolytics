import jwt from "jsonwebtoken";
import User from "../models/user.js";
import { EXCHANGES, publishMessage, ROUTING_KEYS } from "../utils/rabbitmq.js";

const JWT_SECRET = process.env.JWT_SECRET;

export const signUp = async (req, res, next) => {
  try {
    const { name, email, password, gender, age, role } = req.body;

    // Create user
    const newUser = await User.Create(email, password, role);

    const user = {
      user_id: newUser.user_id,
      name,
      email: newUser.email,
      gender,
      age,
      role: newUser.role,
    }

    publishMessage(EXCHANGES.USERS, ROUTING_KEYS.USER_CREATED, user);

    res.status(201).json({
      message: "User created successfully",
      user
    });
  } catch (error) {
    next(error);
  }
};

export const logIn = async (req, res, next) => {
  try {
    const { email, password } = req.body;

    // Find user
    let user = await User.Login(email, password);

    if (!user) {
      return res.status(401).json({
        message: "Invalid email or password",
      });
    }

    // Generate JWT token
    const token = jwt.sign(
      { user_id: user.user_id, role: user.role },
      JWT_SECRET,
      { expiresIn: "7d" },
    );

    res.json({
      message: "Login successful",
      token,
      user: {
        user_id: user.user_id,
        email: user.email,
        role: user.role,
      },
    });
  } catch (error) {
    next(error);
  }
};

export const validateUserExists = async (req, res, next) => {
  try {
    const { user_id } = req.params;

    const user = await User.FindById(user_id);

    if (!user) {
      return res.status(404).json({
        message: "User not found",
      });
    }

    res.status(200).json({
      message: "User exists",
      user: {
        user_id: user.user_id,
        email: user.email,
        role: user.role,
      },
    });
  } catch (error) {
    next(error);
  }
};

export const deleteUser = async (req, res, next) => {
  try {
    const user_id = req.user.user_id;
    const isDeleted = await User.Delete(user_id);

    if (!isDeleted) {
      return res.status(404).json({
        message: "Could not delete user (user may not exist)",
      });
    }

    publishMessage(EXCHANGES.USERS, ROUTING_KEYS.USER_DELETED, { user_id });
    
    res.status(200).json({
      message: "User deleted successfully",
    });
  } catch (error) {
    next(error);
  }
};
