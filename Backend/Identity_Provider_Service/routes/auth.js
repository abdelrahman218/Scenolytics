import express from "express";
import { logIn, signUp, validateUserExists, deleteUser } from "../services/auth.js";
import { signUpRequiredFieldsValidator, logInRequiredFieldsValidator, checkUserExistsValidator, validateJWTToken } from "../validators/auth.js";

const router = express.Router();

// Endpoints
router.post("/signup", signUpRequiredFieldsValidator, checkUserExistsValidator, signUp);
router.post("/login", logInRequiredFieldsValidator, logIn);
router.get("/validate/:user_id", validateUserExists);
router.delete("/delete/:user_id", validateJWTToken, deleteUser);

export default router;