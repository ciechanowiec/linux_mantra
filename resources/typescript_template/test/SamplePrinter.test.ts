import { describe, expect, it } from "vitest";
import { SamplePrinter } from "../src/SamplePrinter.js";

describe("SamplePrinter", () => {
    it("returns the greeting as the first line", async () => {
        const printer: SamplePrinter = new SamplePrinter("Hi");
        const lines: ReadonlyArray<string> = await printer.getLines();
        expect(lines[0]).toBe("Hi");
        expect(lines).toHaveLength(3);
    });
});
