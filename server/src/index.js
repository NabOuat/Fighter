// Salon en ligne de Legendz Fighting (Cloudflare Worker + Durable Object).
//
// Rôle : mettre deux joueurs en relation avec un code de salle à 4 lettres,
// puis faire passer leurs messages (les commandes de chaque frame) de l'un à
// l'autre. Le serveur ne calcule rien du combat : chaque téléphone simule.
//
// Adresses :
//   GET /            -> petit texte pour vérifier que le salon répond
//   GET /new         -> {"code": "KMTA"} : un nouveau code de salle
//   GET /room/KMTA   -> connexion WebSocket à la salle KMTA
//
// Messages envoyés par le serveur (JSON) :
//   {"type": "welcome", "slot": 0 ou 1}  : ta place dans la salle
//   {"type": "start", "seed": nombre}    : les deux joueurs sont là
//   {"type": "left"}                     : l'autre joueur est parti
//   {"type": "full"}                     : la salle est déjà pleine
// Tout autre message d'un joueur est transmis tel quel à l'autre.

import { DurableObject } from "cloudflare:workers";

// Sans I ni O (confondus avec 1 et 0).
const CODE_LETTERS = "ABCDEFGHJKLMNPQRSTUVWXYZ";
const CODE_LENGTH = 4;
// Taille maximale d'un message (les commandes d'une frame tiennent en quelques octets).
const MAX_MESSAGE = 1024;

function randomCode() {
  const bytes = crypto.getRandomValues(new Uint8Array(CODE_LENGTH));
  return Array.from(bytes, (b) => CODE_LETTERS[b % CODE_LETTERS.length]).join("");
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname === "/") {
      return new Response("Legendz Fighting : salon en ligne OK");
    }
    if (url.pathname === "/new") {
      return Response.json({ code: randomCode() });
    }
    const match = url.pathname.match(/^\/room\/([A-Z]{4})$/);
    if (match) {
      // Une salle = un Durable Object, retrouvé par son code.
      const room = env.ROOMS.get(env.ROOMS.idFromName(match[1]));
      return room.fetch(request);
    }
    return new Response("Introuvable", { status: 404 });
  },
};

// Une salle de jeu : deux places au maximum (0 et 1).
export class Room extends DurableObject {
  async fetch(request) {
    if (request.headers.get("Upgrade") !== "websocket") {
      return new Response("Connexion WebSocket attendue", { status: 426 });
    }
    const taken = this.ctx.getWebSockets().map((ws) => ws.deserializeAttachment()?.slot);
    const slot = [0, 1].find((s) => !taken.includes(s));
    const [client, server] = Object.values(new WebSocketPair());

    if (slot === undefined) {
      server.accept();
      server.send(JSON.stringify({ type: "full" }));
      server.close(4000, "full");
      return new Response(null, { status: 101, webSocket: client });
    }

    // « Hibernation » : la salle dort entre deux messages (gratuit et économe).
    this.ctx.acceptWebSocket(server);
    server.serializeAttachment({ slot });
    server.send(JSON.stringify({ type: "welcome", slot }));

    const players = this.ctx.getWebSockets();
    if (players.length === 2) {
      // La même graine pour les deux : le hasard du combat sera identique.
      const seed = crypto.getRandomValues(new Uint32Array(1))[0];
      for (const ws of players) {
        ws.send(JSON.stringify({ type: "start", seed }));
      }
    }
    return new Response(null, { status: 101, webSocket: client });
  }

  // Un message d'un joueur : on le transmet à l'autre.
  async webSocketMessage(ws, message) {
    if (typeof message !== "string" || message.length > MAX_MESSAGE) {
      return;
    }
    for (const other of this.ctx.getWebSockets()) {
      if (other !== ws) {
        other.send(message);
      }
    }
  }

  // Un joueur part : on prévient l'autre.
  async webSocketClose(ws, code) {
    for (const other of this.ctx.getWebSockets()) {
      if (other !== ws) {
        other.send(JSON.stringify({ type: "left" }));
      }
    }
    try {
      ws.close(code === 1005 ? 1000 : code, "bye");
    } catch {
      // Déjà fermée.
    }
  }
}
