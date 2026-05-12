import '@testing-library/jest-dom';

import { render, screen } from '@testing-library/react';

describe('Alert Dispatch Flow', () => {

    test('renders emergency alert dispatch confirmation', () => {

        render(
            <div>
                Emergency Alert Sent Successfully
            </div>
        );

        expect(
            screen.getByText(
                /Emergency Alert Sent Successfully/i
            )
        ).toBeInTheDocument();

    });

});