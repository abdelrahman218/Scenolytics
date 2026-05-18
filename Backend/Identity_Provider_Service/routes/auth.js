import express from "express";
import { logIn, signUp, validateUserExists, deleteUser } from "../services/auth.js";
import { signUpRequiredFieldsValidator, logInRequiredFieldsValidator, checkUserExistsValidator, emailPasswordValuesValidator, signUpValuesValidator, validateJWTToken } from "../validators/auth.js";

const router = express.Router();

// Endpoints
router.post("/signup", signUpRequiredFieldsValidator, emailPasswordValuesValidator, signUpValuesValidator, checkUserExistsValidator, signUp);
router.post("/login", logInRequiredFieldsValidator, emailPasswordValuesValidator, logIn);
router.get("/validate/:user_id", validateUserExists);
router.delete("/delete", validateJWTToken, deleteUser);

export default router;