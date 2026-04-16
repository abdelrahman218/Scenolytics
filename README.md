# 🎬 Scenolytics — Intelligent Direct Casting Platform

> **Misr International University — Faculty of Computer Science | Graduation Project 2025–2026**  
> **Team SWE05** · Yousef Ali · Abdelrahman Ahmed · Mostafa Ayman · Ziad Mohamed  
> **Supervisors:** Prof. Diaa Salama · Eng. Lina Bassel

---

## Table of Contents

- [Overview](#overview)
- [Key Features](#key-features)
- [Architecture](#architecture)
- [Team](#team)

---

## Overview

**Scenolytics** is an AI-powered audition and casting platform that replaces outdated, agency-dependent casting practices with a direct, automated, and fair system. It bridges the gap between directors and actors by eliminating costly middlemen and enabling data-driven talent discovery.

The platform uses **multimodal AI analysis** — combining computer vision, speech emotion recognition, natural language processing, and recommender systems — to objectively evaluate actor performances and generate role-fit recommendations.

---

## Key Features

### For Directors
- **Smart Search & Filters** — Search by role traits: age, gender, ethnicity, body type, personality.
- **AI-Ranked Results** — Audition clips ranked by vocal tone match, script alignment, and emotional authenticity.
- **Audition Management** — Review top candidates, publish auditions with scene scripts, and receive AI-reviewed submissions.

### For Actors
- **Digital Portfolio** — Upload and organize best clips by genre or role type.
- **AI Performance Scoring** — Scored on emotional expression, vocal tone, and script alignment
- **Audition Support** — Submit auditions using director-provided scripts.

---

## Architecture

Scenolytics follows a **microservice architecture**, decoupling the core analysis pipeline from the application layer for scalability and maintainability.

**Key architectural decisions:**
- Role-Based Access Control (RBAC) separates actor and director privileges.
- The AI pipeline is decoupled to allow independent scaling of compute-heavy analysis tasks.
- Human-in-the-loop design: AI provides recommendations, directors retain final decision authority.

---

## Team

| Name | Role |
|---|---|
| Yousef Ali | Team Leader |
| Abdelrahman Ahmed | Team Member |
| Mostafa Ayman | Team Member |
| Ziad Mohamed | Team Member |

**Supervised by:** Prof. Diaa Salama · Eng. Lina Bassel  
**Institution:** Misr International University — Faculty of Computer Science  
**Academic Year:** 2025–2026

---

*Scenolytics — Bridging human creativity and computational intelligence.*