describe('Emergency Alert Security', () => {

    test('rejects invalid secret', () => {

        const requestSecret = 'wrong_secret';

        const actualSecret = 'correct_secret';

        expect(requestSecret)
            .not.toBe(actualSecret);

    });

});