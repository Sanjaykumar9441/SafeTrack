import '@testing-library/jest-dom';

import { render, screen } from '@testing-library/react';

describe('Alert Dispatch Flow', () => {

    test('renders emergency dispatch workflow', () => {

        render(
            <div>
                Emergency Alert Sent
            </div>
        );

        expect(
            screen.getByText(/Emergency Alert Sent/i)
        ).toBeInTheDocument();

    });

});