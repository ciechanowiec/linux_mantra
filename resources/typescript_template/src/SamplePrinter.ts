export class SamplePrinter {
    private readonly greeting: string;

    constructor(greeting: string) {
        this.greeting = greeting;
    }

    async getLines(): Promise<ReadonlyArray<string>> {
        return Promise.resolve([
            this.greeting,
            "This is the first line from a sample file.",
            "This is the second line from a sample file.",
        ]);
    }
}
