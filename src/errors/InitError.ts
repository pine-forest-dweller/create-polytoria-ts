import kleur from "kleur";

import { LoggableError } from "./LoggableError";

export class InitError extends LoggableError {
	constructor(private message: string) {
		super();
	}

	toString() {
		return `create-polytoria-ts ${kleur.red("error")}: ${this.message}`;
	}
}
