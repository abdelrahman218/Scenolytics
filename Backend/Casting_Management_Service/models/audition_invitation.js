import { mysql as knex } from "../config/mysql.js";

export class AuditionInvitation {
  static async create(invitation) {
    await knex("audition_invitations").insert({
      audition_id: invitation.audition_id,
      actor_id: invitation.actor_id,
      invitation_status: "pending",
    });

    const result = await knex('audition_invitations').where({audition_id: invitation.audition_id, actor_id: invitation.actor_id}).first();
    return result;
  }

  static async findById(id){
    const audition_invitation = await knex('audition_invitations')
    .where({ id })
    .first();
    return audition_invitation;
  }

  static async findByAuditionIdAndStatus(audition_id, status) {
    const invitations = await knex("audition_invitations")
      .where({ audition_id, invitation_status: status })
      .orderBy("invited_at", "desc");
    return invitations;
  }

  static async findByActorIdAndStatus(actor_id, status) {
    const invitations = await knex("audition_invitations")
      .where({ actor_id, invitation_status: status })
      .orderBy("invited_at", "desc");
    return invitations;
  }

  static async findByDirectorIdAndStatus(director_id, status) {
    const invitations = await knex("audition_invitations")
      .join("auditions", "audition_invitations.audition_id", "=", "auditions.id")
      .select(
        "audition_invitations.id",
        "director_id",
        "audition_id",
        "actor_id",
        "invitation_status",
        "invited_at",
        "responded_at",
      )
      .where({ director_id, invitation_status: status })
      .orderBy("invited_at", "desc");
    return invitations;
  }

  static async updateStatus(id, status) {
    const updateData = {
      invitation_status: status,
      responded_at: knex.fn.now(),
    };
    await knex("audition_invitations")
      .where({ id })
      .update(updateData);
    
    const result = await knex("audition_invitations").where({ id }).first();
    return result;
  }

  static async deleteByActorId(actor_id) {
    const result = await knex('audition_invitations')
      .where({ actor_id })
      .del();
    return result;
  }
}
